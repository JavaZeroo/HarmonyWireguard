#include "tun_interface.h"
#include <unistd.h>
#include <errno.h>

ssize_t TunRead(int32_t tunFd, uint8_t* buffer, size_t bufferLen) {
    if (tunFd < 0 || !buffer || bufferLen == 0) return -1;
    return read(tunFd, buffer, bufferLen);
}

ssize_t TunWrite(int32_t tunFd, const uint8_t* data, size_t len) {
    if (tunFd < 0 || !data || len == 0) return -1;
    return write(tunFd, data, len);
}
