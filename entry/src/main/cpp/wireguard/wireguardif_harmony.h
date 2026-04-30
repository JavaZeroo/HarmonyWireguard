#ifndef WIREGUARDIF_HARMONY_H
#define WIREGUARDIF_HARMONY_H

#include <cstdint>
#include <cstddef>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct wireguard_device;
struct wireguard_peer;

// 初始化 WireGuard 设备
bool wg_device_init(const uint8_t *private_key);

// 添加 Peer，返回 peer 指针（失败返回 NULL）
struct wireguard_peer *wg_add_peer(const uint8_t *public_key, const uint8_t *preshared_key);

// 设置 Peer Endpoint（IPv4 地址和网络字节序端口）
void wg_set_peer_endpoint(struct wireguard_peer *peer, uint32_t ip, uint16_t port);

// 设置 Peer Keepalive 间隔（秒）
void wg_set_peer_keepalive(struct wireguard_peer *peer, uint16_t keepalive);

// 启动握手，输出握手包到 packet_out，返回 true 成功
bool wg_start_handshake(struct wireguard_peer *peer, uint8_t *packet_out, size_t *packet_len);

// 处理收到的数据包
// 返回 >0: 明文长度（数据包已解密写入 dst）, 0: 握手包已处理, -1: 错误
int wg_process_packet(const uint8_t *packet_in, size_t packet_len, uint8_t *dst, size_t dst_len, struct wireguard_peer **out_peer);

// 加密数据包
bool wg_encrypt_packet(struct wireguard_peer *peer, const uint8_t *src, size_t src_len, uint8_t *dst, size_t *dst_len);

// 定时器 tick（每 100ms 调用一次）
void wg_timer_tick(void);

// 获取设备状态
bool wg_device_is_inited(void);
struct wireguard_device *wg_get_device(void);

#ifdef __cplusplus
}
#endif

#endif // WIREGUARDIF_HARMONY_H
