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

static std::atomic<bool> g_ioRunning{false};
static std::thread g_tunToUdpThread;
static std::thread g_udpToTunThread;
static std::thread g_timerThread;

static int32_t g_tunFd = -1;
static int32_t g_udpFd = -1;

// 辅助：发送握手 initiation 包
static bool SendHandshakeInitiation(struct wireguard_peer *peer) {
    uint8_t handshakeBuf[256];
    size_t handshakeLen = 0;
    if (wg_start_handshake(peer, handshakeBuf, &handshakeLen)) {
        ssize_t s = UdpSocketSend(g_udpFd, handshakeBuf, handshakeLen);
        return s > 0;
    }
    return false;
}

// 从 TUN 读取 -> WireGuard 加密 -> UDP 发送
static void TunToUdpThread() {
    constexpr size_t BUFFER_SIZE = 2048;
    uint8_t plainBuf[BUFFER_SIZE];
    uint8_t encBuf[BUFFER_SIZE];
    uint64_t count = 0;

    WG_LOGI("TUN->UDP thread started");
    struct wireguard_device *dev = wg_get_device();

    while (g_ioRunning) {
        ssize_t plainLen = TunRead(g_tunFd, plainBuf, BUFFER_SIZE);
        if (plainLen < 0) {
            if (errno != EAGAIN && errno != EINTR) {
                WG_LOGE("TunRead error: %{public}d", errno);
                break;
            }
            usleep(1000);
            continue;
        }
        if (plainLen == 0) {
            usleep(1000);
            continue;
        }

        // Phase 3: WireGuard 加密转发
        bool sent = false;
        for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
            struct wireguard_peer *peer = &dev->peers[i];
            if (!peer->valid) continue;

            // 如果需要握手，先发送握手包
            if (peer->send_handshake) {
                peer->send_handshake = false;
                SendHandshakeInitiation(peer);
            }

            if (!peer->curr_keypair.valid) continue;

            size_t encLen = BUFFER_SIZE;
            if (wg_encrypt_packet(peer, plainBuf, plainLen, encBuf, &encLen)) {
                ssize_t s = UdpSocketSend(g_udpFd, encBuf, encLen);
                if (s < 0) {
                    WG_LOGE("UdpSocketSend error: %{public}d", errno);
                } else {
                    sent = true;
                    count++;
                }
                break;
            }
        }

        if (!sent) {
            WG_LOGI("No active peer session, packet dropped");
        }

        if (count % 100 == 0) {
            WG_LOGI("TUN->UDP packets encrypted: %{public}lu", count);
        }
    }
    WG_LOGI("TUN->UDP thread exited, total=%{public}lu", count);
}

// 从 UDP 接收 -> WireGuard 解密 -> TUN 写入
static void UdpToTunThread() {
    constexpr size_t BUFFER_SIZE = 2048;
    uint8_t encBuf[BUFFER_SIZE];
    uint8_t plainBuf[BUFFER_SIZE];
    uint64_t count = 0;

    WG_LOGI("UDP->TUN thread started");
    struct wireguard_device *dev = wg_get_device();

    while (g_ioRunning) {
        ssize_t encLen = UdpSocketRecv(g_udpFd, encBuf, BUFFER_SIZE);
        if (encLen < 0) {
            if (errno != EAGAIN && errno != EINTR) {
                WG_LOGE("UdpSocketRecv error: %{public}d", errno);
                break;
            }
            usleep(1000);
            continue;
        }
        if (encLen == 0) {
            usleep(1000);
            continue;
        }

        // Phase 3: WireGuard 解密转发
        struct wireguard_peer *peer = nullptr;
        int result = wg_process_packet(encBuf, encLen, plainBuf, BUFFER_SIZE, &peer);

        if (result > 0) {
            // 解密成功，写入 TUN
            ssize_t written = TunWrite(g_tunFd, plainBuf, result);
            if (written < 0) {
                WG_LOGE("TunWrite error: %{public}d", errno);
            } else {
                count++;
            }
        } else if (result == 0) {
            // 握手包已处理
            WG_LOGI("Handshake packet processed");
        } else {
            // 未知或错误包，忽略
        }

        // 检查是否需要发送握手（keepalive 或重协商）
        if (peer && peer->send_handshake) {
            peer->send_handshake = false;
            SendHandshakeInitiation(peer);
        }

        if (count % 100 == 0) {
            WG_LOGI("UDP->TUN packets decrypted: %{public}lu", count);
        }
    }
    WG_LOGI("UDP->TUN thread exited, total=%{public}lu", count);
}

// WireGuard 定时器线程
static void TimerThread() {
    WG_LOGI("WireGuard timer thread started");
    while (g_ioRunning) {
        wg_timer_tick();
        usleep(100000); // 100ms
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
    if (g_tunToUdpThread.joinable()) {
        g_tunToUdpThread.join();
    }
    if (g_udpToTunThread.joinable()) {
        g_udpToTunThread.join();
    }
    if (g_timerThread.joinable()) {
        g_timerThread.join();
    }
    g_tunFd = -1;
    g_udpFd = -1;
    WG_LOGI("PacketIO stopped");
}
