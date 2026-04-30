#ifndef UDP_SOCKET_H
#define UDP_SOCKET_H

#include <cstdint>
#include <string>
#include <sys/types.h>
#include <unistd.h>

// 创建 UDP socket 并连接到指定 endpoint
// 返回 socket fd，失败返回 -1
int32_t CreateUdpSocket(const std::string& ip, uint16_t port);

// 关闭 socket
void CloseUdpSocket(int32_t fd);

// 发送数据到已连接的 endpoint
ssize_t UdpSocketSend(int32_t fd, const uint8_t* data, size_t len);

// 接收数据
ssize_t UdpSocketRecv(int32_t fd, uint8_t* buffer, size_t bufferLen);

#endif // UDP_SOCKET_H
