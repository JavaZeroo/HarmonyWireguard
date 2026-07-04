// 鸿蒙 HarmonyOS WireGuard 接口适配层
// 替代 wireguardif.c（原依赖 lwIP），提供设备初始化、Peer 管理、握手驱动
// 网络 I/O 由外部 packet_io.cpp 处理

#include "wireguardif_harmony.h"
#include "wireguard.h"
#include "crypto.h"
#include "lwip_compat.h"
#include <string.h>
#include <stdlib.h>

// 日志宏（避免依赖外部头文件路径问题）
#include <hilog/log.h>
#define HARMONY_WG_LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, 0xA001, "WireGuard", fmt, ##__VA_ARGS__)

static struct wireguard_device g_device;
static bool g_device_inited = false;

// 初始化 WireGuard 设备
bool wg_device_init(const uint8_t *private_key)
{
    if (g_device_inited) {
        HARMONY_WG_LOGI("WireGuard device already initialized");
        return true;
    }
    wireguard_init();
    memset(&g_device, 0, sizeof(g_device));
    bool result = wireguard_device_init(&g_device, private_key);
    g_device_inited = result;
    HARMONY_WG_LOGI("WireGuard device init: %{public}d", result);
    return result;
}

// 添加 Peer
struct wireguard_peer *wg_add_peer(const uint8_t *public_key, const uint8_t *preshared_key)
{
    if (!g_device_inited) return NULL;
    struct wireguard_peer *peer = peer_alloc(&g_device);
    if (!peer) return NULL;
    if (!wireguard_peer_init(&g_device, peer, public_key, preshared_key)) {
        peer->valid = false;
        return NULL;
    }
    HARMONY_WG_LOGI("Peer added, index=%{public}d", wireguard_peer_index(&g_device, peer));
    return peer;
}

// 更新 Peer Endpoint
void wg_set_peer_endpoint(struct wireguard_peer *peer, uint32_t ip, uint16_t port)
{
    if (!peer) return;
    peer->connect_ip.u_addr.addr = ip;
    peer->connect_port = port;
    peer->active = true;
}

// 设置 Peer Keepalive 间隔
void wg_set_peer_keepalive(struct wireguard_peer *peer, uint16_t keepalive)
{
    if (!peer) return;
    peer->keepalive_interval = keepalive;
}

// 启动握手（发送 Handshake Initiation）
bool wg_start_handshake(struct wireguard_peer *peer, uint8_t *packet_out, size_t *packet_len)
{
    if (!peer || !g_device_inited) return false;
    struct message_handshake_initiation msg;
    memset(&msg, 0, sizeof(msg));
    if (!wireguard_create_handshake_initiation(&g_device, peer, &msg)) {
        return false;
    }
    memcpy(packet_out, &msg, sizeof(msg));
    *packet_len = sizeof(msg);
    peer->last_initiation_tx = wireguard_sys_now();
    HARMONY_WG_LOGI("Handshake initiation sent");
    return true;
}

// 处理收到的数据包（握手响应或数据包）
// 返回 0: 已处理, 1: 数据包（已解密写入 dst）, -1: 错误
int wg_process_packet(const uint8_t *packet_in, size_t packet_len, uint8_t *dst, size_t dst_len, struct wireguard_peer **out_peer)
{
    if (!g_device_inited || !packet_in || packet_len < 4) return -1;

    uint8_t type = wireguard_get_message_type(packet_in, packet_len);

    switch (type) {
        case MESSAGE_HANDSHAKE_RESPONSE: {
            if (packet_len < sizeof(struct message_handshake_response)) return -1;
            struct message_handshake_response msg;
            memcpy(&msg, packet_in, sizeof(msg));
            struct wireguard_peer *peer = peer_lookup_by_handshake(&g_device, msg.receiver);
            if (!peer) return -1;
            if (wireguard_process_handshake_response(&g_device, peer, &msg)) {
                // 我们是发起方(initiator)——收到响应后必须以 initiator=true 建会话，
                // 否则 KDF2 会把 sending/receiving key 派生反，且会话被放进 next_keypair 而非 curr。
                wireguard_start_session(peer, true);
                HARMONY_WG_LOGI("Handshake response processed, session started (initiator)");
                return 0;
            }
            return -1;
        }

        case MESSAGE_COOKIE_REPLY: {
            if (packet_len < sizeof(struct message_cookie_reply)) return -1;
            // 简化：暂不支持 cookie reply
            return 0;
        }

        case MESSAGE_TRANSPORT_DATA: {
            if (packet_len < sizeof(struct message_transport_data) + 16) return -1;
            // WireGuard 线格式的 receiver 索引与 counter 都是【小端】。
            // receiver 要与我方 local_index(本机字节序)比对，counter 是 AEAD nonce，
            // 二者都必须按小端读取——之前用大端手工解析在小端 ARM 上必然匹配/解密失败。
            const struct message_transport_data *data =
                reinterpret_cast<const struct message_transport_data *>(packet_in);
            uint32_t receiver = data->receiver;
            uint64_t counter = U8TO64_LITTLE(data->counter);

            struct wireguard_peer *peer = peer_lookup_by_receiver(&g_device, receiver);
            if (!peer) return -1;

            struct wireguard_keypair *keypair = get_peer_keypair_for_idx(peer, receiver);
            if (!keypair || !keypair->receiving_valid) return -1;

            size_t enc_len = packet_len - sizeof(struct message_transport_data);
            if (enc_len > dst_len) return -1;

            if (!wireguard_decrypt_packet(dst, packet_in + sizeof(struct message_transport_data),
                                          enc_len, counter, keypair)) {
                return -1;
            }

            keypair->last_rx = wireguard_sys_now();
            peer->last_rx = wireguard_sys_now();
            if (out_peer) *out_peer = peer;
            return (int)(enc_len - WIREGUARD_AUTHTAG_LEN);
        }

        default:
            return -1;
    }
}

// 加密数据包（允许 src_len=0，用于 keepalive 空包）
bool wg_encrypt_packet(struct wireguard_peer *peer, const uint8_t *src, size_t src_len, uint8_t *dst, size_t *dst_len)
{
    if (!peer || !g_device_inited) return false;

    // 优先 curr_keypair；若无效，尝试 next_keypair（刚握手完成尚未提升）；最后 prev_keypair
    struct wireguard_keypair *keypair = &peer->curr_keypair;
    bool using_next = false;
    if (!keypair->valid || !keypair->sending_valid) {
        keypair = &peer->next_keypair;
        if (keypair->valid && keypair->sending_valid) {
            using_next = true;
        } else {
            keypair = &peer->prev_keypair;
            if (!keypair->valid || !keypair->sending_valid) {
                return false;
            }
        }
    }

    // 完整 transport data 包 = header(16) + 密文(src_len) + Poly1305 认证标签(16)
    size_t total_len = sizeof(struct message_transport_data) + src_len + WIREGUARD_AUTHTAG_LEN;
    if (*dst_len < total_len) return false;

    struct message_transport_data *msg = (struct message_transport_data *)dst;
    msg->type = MESSAGE_TRANSPORT_DATA;
    memset(msg->reserved, 0, 3);
    msg->receiver = keypair->remote_index;
    // 包内 counter 必须 = 加密用的 nonce（即递增前的值）
    U64TO8_LITTLE(msg->counter, keypair->sending_counter);

    // wireguard_encrypt_packet 内部已经 sending_counter++，这里不要再自增（否则双重递增）
    wireguard_encrypt_packet(msg->enc_packet, src, src_len, keypair);

    keypair->last_tx = wireguard_sys_now();
    peer->last_tx = wireguard_sys_now();
    *dst_len = total_len;

    // 用 next_keypair 成功加密一笔 -> 提升 next 为 curr，原 curr 变 prev
    if (using_next) {
        memset(&peer->prev_keypair, 0, sizeof(peer->prev_keypair));
        peer->prev_keypair = peer->curr_keypair;
        peer->curr_keypair = peer->next_keypair;
        memset(&peer->next_keypair, 0, sizeof(peer->next_keypair));
        HARMONY_WG_LOGI("Keypair promoted: next -> curr");
    }
    return true;
}

// 定时器 tick（由外部线程调用，建议每 100ms 一次）
void wg_timer_tick(void)
{
    if (!g_device_inited) return;

    uint32_t now = wireguard_sys_now();
    for (int i = 0; i < WIREGUARD_MAX_PEERS; i++) {
        struct wireguard_peer *peer = &g_device.peers[i];
        if (!peer->valid) continue;

        // 1. 如果 peer 没有任何有效会话(curr/next 都无效)且 active，尝试发送握手
        //    next_keypair 有效说明刚握手完成，等首个数据包提升即可，无需重复握手
        if (peer->active && !peer->curr_keypair.valid && !peer->next_keypair.valid) {
            if (wireguard_expired(peer->last_initiation_tx, REKEY_TIMEOUT)) {
                peer->send_handshake = true;
            }
        }

        // 2. 检查是否需要重新握手
        if (peer->curr_keypair.valid) {
            if (wireguard_expired(peer->curr_keypair.keypair_millis, REKEY_AFTER_TIME) ||
                (peer->curr_keypair.sending_counter > REKEY_AFTER_MESSAGES)) {
                peer->send_handshake = true;
            }
        }

        // 注意：keepalive 不在这里处理。keepalive 是【加密的空数据包】，不是新握手；
        // 由 packet_io.cpp 的 FlushKeepalives() 直接用 wg_encrypt_packet 发送。
    }
}

// 获取设备状态
bool wg_device_is_inited(void) { return g_device_inited; }
struct wireguard_device *wg_get_device(void) { return &g_device; }
