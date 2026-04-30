#include "udp_socket.h"
#include <hilog/log.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "UdpSocket"

#define UDP_LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define UDP_LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)

int32_t CreateUdpSocket(const std::string& ip, uint16_t port) {
    int32_t fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        UDP_LOGE("socket() failed: %{public}d", errno);
        return -1;
    }

    // 设置非阻塞
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(ip.c_str());

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        UDP_LOGE("connect() failed: %{public}d", errno);
        close(fd);
        return -1;
    }

    UDP_LOGI("UDP socket created, fd=%{public}d, endpoint=%{public}s:%{public}d", fd, ip.c_str(), port);
    return fd;
}

void CloseUdpSocket(int32_t fd) {
    if (fd >= 0) {
        close(fd);
        UDP_LOGI("UDP socket closed, fd=%{public}d", fd);
    }
}

ssize_t UdpSocketSend(int32_t fd, const uint8_t* data, size_t len) {
    if (fd < 0 || !data || len == 0) return -1;
    return send(fd, data, len, 0);
}

ssize_t UdpSocketRecv(int32_t fd, uint8_t* buffer, size_t bufferLen) {
    if (fd < 0 || !buffer || bufferLen == 0) return -1;
    return recv(fd, buffer, bufferLen, 0);
}
