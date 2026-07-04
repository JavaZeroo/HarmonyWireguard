#ifndef PACKET_IO_H
#define PACKET_IO_H

#include <cstdint>

// 启动数据泵：tunFd <-> udpFd 双向转发，并启动 WireGuard 定时器线程
int32_t StartPacketIO(int32_t tunFd, int32_t udpFd);

// 停止数据泵
void StopPacketIO();

// 主动为设备上所有 active 的 peer 发起一次握手
// 用于刚配置完 peer 时立即建立会话，而不等待第一笔出口流量
void KickInitialHandshake();

// 读取累计收发字节数（UDP 线路字节，与 `wg show transfer` 口径一致）。
// 线程安全（原子读）。StartPacketIO 时归零。
void GetTrafficStats(uint64_t *rxBytes, uint64_t *txBytes);

#endif // PACKET_IO_H
