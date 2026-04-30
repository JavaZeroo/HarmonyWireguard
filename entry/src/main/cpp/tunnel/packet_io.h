#ifndef PACKET_IO_H
#define PACKET_IO_H

#include <cstdint>

// 启动数据泵：tunFd <-> udpFd 双向转发
// 目前 Phase 2 为 UDP 透传，Phase 3 接入 WireGuard 加密
int32_t StartPacketIO(int32_t tunFd, int32_t udpFd);

// 停止数据泵
void StopPacketIO();

#endif // PACKET_IO_H
