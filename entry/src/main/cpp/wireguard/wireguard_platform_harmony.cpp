// 鸿蒙 HarmonyOS 平台适配层
// 实现 wireguard-platform.h 中声明的平台相关函数

#include "wireguard-platform.h"
#include "lwip_compat.h"
#include <hilog/log.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "WGPlatform"

#define PLAT_LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define PLAT_LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)

// lwIP 兼容：sys_now 返回系统启动后的毫秒数
extern "C" u32_t sys_now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (u32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

// WireGuard 平台：获取当前毫秒时间
extern "C" uint32_t wireguard_sys_now()
{
    return sys_now();
}

// WireGuard 平台：填充随机字节
extern "C" void wireguard_random_bytes(void *bytes, size_t size)
{
    if (!bytes || size == 0) return;

    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0) {
        PLAT_LOGE("Failed to open /dev/urandom: %{public}d", errno);
        // 降级：使用当前时间作为伪随机种子
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        uint8_t *ptr = (uint8_t *)bytes;
        for (size_t i = 0; i < size; i++) {
            ptr[i] = (uint8_t)(ts.tv_nsec ^ (i * 7));
        }
        return;
    }

    ssize_t total = 0;
    while ((size_t)total < size) {
        ssize_t ret = read(fd, (uint8_t *)bytes + total, size - total);
        if (ret > 0) {
            total += ret;
        } else {
            break;
        }
    }
    close(fd);

    if ((size_t)total < size) {
        PLAT_LOGE("Failed to read enough random bytes: %{public}zd/%{public}zu", total, size);
    }
}

// WireGuard 平台：获取 tai64n 格式时间（12字节：8秒 + 4纳秒）
extern "C" void wireguard_tai64n_now(uint8_t *output)
{
    if (!output) return;

    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);

    // TAI64N = TAI seconds (64-bit big-endian) + nanoseconds (32-bit big-endian)
    // 简化：使用 Unix 时间 + 0x4000000000000000 (TAI offset)
    uint64_t tai_seconds = (uint64_t)ts.tv_sec + 0x4000000000000000ULL;
    uint32_t nanoseconds = (uint32_t)ts.tv_nsec;

    // 大端序写入
    for (int i = 0; i < 8; i++) {
        output[i] = (uint8_t)(tai_seconds >> (56 - i * 8));
    }
    for (int i = 0; i < 4; i++) {
        output[8 + i] = (uint8_t)(nanoseconds >> (24 - i * 8));
    }
}

// WireGuard 平台：系统是否处于高负载
extern "C" bool wireguard_is_under_load()
{
    // 鸿蒙上简化处理：始终返回 false
    return false;
}
