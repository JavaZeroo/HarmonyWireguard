#include "packet_io.h"
#include "tun_interface.h"
#include "udp_socket.h"
#include "wireguard/wireguard.h"
#include "wireguard/wireguardif_harmony.h"
#include "utils/logger.h"
#include <thread>
#include <atomic>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>

static std::atomic<bool> g_ioRunning{false};
static std::thread g_tunToUdpThread;
static std::thread g_udpToTunThread;
static std::thread g_timerThread;

static int32_t g_tunFd = -1;
static int32_t g_udpFd = -1;

// 累计收发字节（UDP 线路字节）。原子，供 GetTrafficStats 跨线程读取。
static std::atomic<uint64_t> g_rxBytes{0};
static std::atomic<uint64_t> g_txBytes{0};

void GetTrafficStats(uint64_t *rxBytes, uint64_t *txBytes) {
    if (rxBytes) *rxBytes = g_rxBytes.load(std::memory_order_relaxed);
    if (txBytes) *txBytes = g_txBytes.load(std::memory_order_relaxed);
}

static void SetNonBlocking(int32_t fd) {
    if (fd < 0) return;
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) {
        WG_LOGE("fcntl GETFL failed: fd=%{public}d errno=%{public}d", fd, errno);
        return;
    }
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        WG_LOGE("fcntl SETFL O_NONBLOCK failed: fd=%{public}d errno=%{public}d", fd, errno);
    }
}

// 发送一次握手包给指定 peer
static bool SendHandshakeForPeer(struct wireguard_peer *peer) {
    if (!peer || g_udpFd < 0) return false;

    // 严格遵守 WireGuard 协议 REKEY_TIMEOUT(5秒)
    // 上一次发握手在 5 秒内的话，不再重发，否则会让服务器把我们当 DDoS 静默丢弃
    if (peer->last_initiation_tx != 0 &&
        !wireguard_expired(peer->last_initiation_tx, REKEY_TIMEOUT)) {
        return false;
    }

    // 如果已经有有效会话(curr 或 next)，不需要重新握手
    if (peer->curr_keypair.valid || peer->next_keypair.valid) {
        return false;
    }

    uint8_t buf[256];
    size_t len = 0;
    if (!wg_start_handshake(peer, buf, &len)) {
        WG_LOGE("wg_start_handshake failed");
        return false;
    }
    ssize_t s = UdpSocketSend(g_udpFd, buf, len);
    if (s < 0) {
        WG_LOGE("Handshake send failed: errno=%{public}d", errno);
        return false;
    }
    g_txBytes.fetch_add((uint64_t)s, std::memory_order_relaxed);
    WG_LOGI("Handshake initiation sent, %{public}zd bytes", s);
    return true;
}

// 扫描所有 peer，把标记为 send_handshake 的发出去
static void FlushPendingHandshakes() {
    struct wireguard_device *dev = wg_get_device();
    if (!dev) return;
    for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
        struct wireguard_peer *peer = &dev->peers[i];
        if (!peer->valid) continue;
        if (peer->send_handshake) {
            peer->send_handshake = false;
            SendHandshakeForPeer(peer);
        }
    }
}

// 发送 keepalive（加密的空数据包）。两种触发：
//  a) 会话刚建立、我方尚未发过任何数据包(last_tx==0) —— WireGuard 协议要求 initiator
//     先发一个包，responder 才会把会话标记为可发送，否则服务器不会回数据；
//  b) persistentKeepalive 到期，维持 NAT 映射。
static void FlushKeepalives() {
    struct wireguard_device *dev = wg_get_device();
    if (!dev || g_udpFd < 0) return;
    for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
        struct wireguard_peer *peer = &dev->peers[i];
        if (!peer->valid) continue;
        if (!peer->curr_keypair.valid || !peer->curr_keypair.sending_valid) continue;

        bool needInitial = (peer->last_tx == 0);
        bool needPeriodic = (peer->keepalive_interval > 0 &&
                             wireguard_expired(peer->last_tx, peer->keepalive_interval));
        if (!needInitial && !needPeriodic) continue;

        uint8_t enc[64];
        size_t encLen = sizeof(enc);
        if (wg_encrypt_packet(peer, nullptr, 0, enc, &encLen)) {
            ssize_t s = UdpSocketSend(g_udpFd, enc, encLen);
            if (s > 0) {
                g_txBytes.fetch_add((uint64_t)s, std::memory_order_relaxed);
                WG_LOGI("Keepalive sent, %{public}zu bytes (initial=%{public}d)",
                        encLen, needInitial ? 1 : 0);
            } else {
                WG_LOGE("Keepalive send failed: errno=%{public}d", errno);
            }
        }
    }
}

// 从 TUN 读取 -> WireGuard 加密 -> UDP 发送
static void TunToUdpThread() {
    constexpr size_t BUFFER_SIZE = 2048;
    uint8_t plainBuf[BUFFER_SIZE];
    uint8_t encBuf[BUFFER_SIZE + 64];
    uint64_t count = 0;
    uint64_t drops = 0;

    WG_LOGI("TUN->UDP thread started");
    struct wireguard_device *dev = wg_get_device();

    struct pollfd pfd{};
    pfd.fd = g_tunFd;
    pfd.events = POLLIN;

    while (g_ioRunning) {
        int pr = poll(&pfd, 1, 200);
        if (pr < 0) {
            if (errno == EINTR) continue;
            WG_LOGE("TUN poll error: %{public}d", errno);
            break;
        }
        if (pr == 0) continue;
        if (!(pfd.revents & POLLIN)) continue;

        ssize_t plainLen = TunRead(g_tunFd, plainBuf, BUFFER_SIZE);
        if (plainLen <= 0) {
            if (plainLen < 0 && errno != EAGAIN && errno != EINTR && errno != EWOULDBLOCK) {
                WG_LOGE("TunRead error: %{public}d", errno);
                break;
            }
            continue;
        }

        // 找一个有有效会话的 peer 加密发送（curr 或 next 任一有效都行）
        bool sent = false;
        for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
            struct wireguard_peer *peer = &dev->peers[i];
            if (!peer->valid) continue;
            if (!peer->curr_keypair.valid && !peer->next_keypair.valid) continue;

            size_t encLen = sizeof(encBuf);
            if (wg_encrypt_packet(peer, plainBuf, (size_t)plainLen, encBuf, &encLen)) {
                ssize_t s = UdpSocketSend(g_udpFd, encBuf, encLen);
                if (s < 0) {
                    WG_LOGE("UdpSocketSend error: %{public}d", errno);
                } else {
                    g_txBytes.fetch_add((uint64_t)s, std::memory_order_relaxed);
                    sent = true;
                    count++;
                    if (count <= 3) {
                        WG_LOGI("DATA sent #%{public}lu: plain=%{public}zd enc=%{public}zu udp_sent=%{public}zd",
                                (unsigned long)count, plainLen, encLen, s);
                    }
                }
                break;
            }
        }

        if (!sent) {
            drops++;
            // 没有可用会话且 next 也无效时才排队握手
            for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
                struct wireguard_peer *peer = &dev->peers[i];
                if (peer->valid && peer->active &&
                    !peer->curr_keypair.valid && !peer->next_keypair.valid) {
                    peer->send_handshake = true;
                }
            }
            if ((drops & 0x3F) == 0) {
                WG_LOGI("TUN packet dropped (no session), drops=%{public}lu", (unsigned long)drops);
            }
        } else if ((count & 0x7F) == 0) {
            WG_LOGI("TUN->UDP packets encrypted: %{public}lu", (unsigned long)count);
        }
    }
    WG_LOGI("TUN->UDP thread exited, sent=%{public}lu drops=%{public}lu",
            (unsigned long)count, (unsigned long)drops);
}

// 从 UDP 接收 -> WireGuard 解密 -> TUN 写入
static void UdpToTunThread() {
    constexpr size_t BUFFER_SIZE = 2048;
    uint8_t encBuf[BUFFER_SIZE + 64];
    uint8_t plainBuf[BUFFER_SIZE];
    uint64_t count = 0;

    WG_LOGI("UDP->TUN thread started");

    struct pollfd pfd{};
    pfd.fd = g_udpFd;
    pfd.events = POLLIN;

    while (g_ioRunning) {
        int pr = poll(&pfd, 1, 200);
        if (pr < 0) {
            if (errno == EINTR) continue;
            WG_LOGE("UDP poll error: %{public}d", errno);
            break;
        }
        if (pr == 0) continue;
        if (!(pfd.revents & POLLIN)) continue;

        ssize_t encLen = UdpSocketRecv(g_udpFd, encBuf, sizeof(encBuf));
        if (encLen <= 0) {
            if (encLen < 0 && errno != EAGAIN && errno != EINTR && errno != EWOULDBLOCK) {
                WG_LOGE("UdpSocketRecv error: %{public}d", errno);
                break;
            }
            continue;
        }
        g_rxBytes.fetch_add((uint64_t)encLen, std::memory_order_relaxed);

        // 收到任何 UDP 包都打日志 —— 用于判断"包到底有没有从服务器回来"
        uint8_t msgType = encBuf[0];
        WG_LOGI("UDP RECV: %{public}zd bytes, msgType=%{public}u (1=init 2=resp 3=cookie 4=data)",
                encLen, (unsigned)msgType);

        struct wireguard_peer *peer = nullptr;
        int result = wg_process_packet(encBuf, (size_t)encLen, plainBuf, BUFFER_SIZE, &peer);

        if (result > 0) {
            ssize_t written = TunWrite(g_tunFd, plainBuf, result);
            if (written < 0) {
                WG_LOGE("TunWrite error: %{public}d", errno);
            } else {
                count++;
                if ((count & 0x7F) == 0) {
                    WG_LOGI("UDP->TUN packets decrypted: %{public}lu", (unsigned long)count);
                }
            }
        } else if (result == 0) {
            WG_LOGI("Handshake / control packet processed");
        } else {
            // 之前没打这条 —— 服务器若回包但被拒绝 (key/MAC 不匹配等) 也算这一类
            WG_LOGE("wg_process_packet REJECTED: result=%{public}d encLen=%{public}zd msgType=%{public}u",
                    result, encLen, (unsigned)msgType);
        }
        // 由 TimerThread 统一发送排队中的握手
    }
    WG_LOGI("UDP->TUN thread exited, decrypted=%{public}lu", (unsigned long)count);
}

// WireGuard 定时器线程：tick + 主动发送排队中的握手 / keepalive
static void TimerThread() {
    WG_LOGI("WireGuard timer thread started");
    while (g_ioRunning) {
        wg_timer_tick();
        FlushPendingHandshakes();
        FlushKeepalives();
        // 100ms 总粒度，分 10 次 10ms 睡眠以快速响应停止
        for (int i = 0; i < 10 && g_ioRunning; i++) {
            usleep(10000);
        }
    }
    WG_LOGI("WireGuard timer thread exited");
}

int32_t StartPacketIO(int32_t tunFd, int32_t udpFd) {
    if (g_ioRunning) {
        StopPacketIO();
    }
    if (tunFd < 0 || udpFd < 0) {
        WG_LOGE("Invalid fds: tun=%{public}d, udp=%{public}d", tunFd, udpFd);
        return -1;
    }

    g_tunFd = tunFd;
    g_udpFd = udpFd;
    g_rxBytes.store(0, std::memory_order_relaxed);
    g_txBytes.store(0, std::memory_order_relaxed);
    SetNonBlocking(g_tunFd);
    SetNonBlocking(g_udpFd);

    g_ioRunning = true;
    g_tunToUdpThread = std::thread(TunToUdpThread);
    g_udpToTunThread = std::thread(UdpToTunThread);
    g_timerThread = std::thread(TimerThread);
    WG_LOGI("PacketIO started, tunFd=%{public}d, udpFd=%{public}d", tunFd, udpFd);
    return 0;
}

void StopPacketIO() {
    if (!g_ioRunning) return;
    g_ioRunning = false;
    if (g_tunToUdpThread.joinable()) g_tunToUdpThread.join();
    if (g_udpToTunThread.joinable()) g_udpToTunThread.join();
    if (g_timerThread.joinable()) g_timerThread.join();
    g_tunFd = -1;
    g_udpFd = -1;
    WG_LOGI("PacketIO stopped");
}

void KickInitialHandshake() {
    struct wireguard_device *dev = wg_get_device();
    if (!dev) {
        WG_LOGE("KickInitialHandshake: device not ready");
        return;
    }
    int kicked = 0;
    for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
        struct wireguard_peer *peer = &dev->peers[i];
        if (!peer->valid || !peer->active) continue;
        if (SendHandshakeForPeer(peer)) kicked++;
    }
    WG_LOGI("KickInitialHandshake: %{public}d peer(s) kicked", kicked);
}
