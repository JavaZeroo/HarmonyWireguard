#ifndef TUN_INTERFACE_H
#define TUN_INTERFACE_H

#include <cstdint>
#include <cstddef>
#include <sys/types.h>
#include <unistd.h>

// 从 TUN fd 读取一个 IP 包
// 返回读取的字节数，0 表示无数据，-1 表示错误
ssize_t TunRead(int32_t tunFd, uint8_t* buffer, size_t bufferLen);

// 向 TUN fd 写入一个 IP 包
// 返回写入的字节数，-1 表示错误
ssize_t TunWrite(int32_t tunFd, const uint8_t* data, size_t len);

#endif // TUN_INTERFACE_H
