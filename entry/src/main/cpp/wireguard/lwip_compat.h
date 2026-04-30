#ifndef LWIP_COMPAT_H
#define LWIP_COMPAT_H

// 鸿蒙适配层：为 wireguard-lwip 提供 lwIP 类型的最小兼容定义
// Phase 3 中逐步替换为鸿蒙原生类型或直接移除 lwIP 依赖

#include <stdint.h>
#include <stdbool.h>
#include <netinet/in.h>

#ifdef __cplusplus
extern "C" {
#endif

// lwIP 基本类型别名
typedef uint8_t   u8_t;
typedef int8_t    s8_t;
typedef uint16_t  u16_t;
typedef int16_t   s16_t;
typedef uint32_t  u32_t;
typedef int32_t   s32_t;

// lwIP 错误码
typedef s8_t err_t;
#define ERR_OK    0
#define ERR_MEM  -1
#define ERR_ARG  -15

// IP 地址类型（简化版，仅支持 IPv4）
typedef struct ip4_addr {
    u32_t addr;
} ip4_addr_t;

typedef struct ip_addr {
    u8_t type;
    ip4_addr_t u_addr;
} ip_addr_t;

#define IPADDR_TYPE_V4 0
#define IPADDR_TYPE_ANY 6

#define IP4_ADDR(ipaddr, a,b,c,d) \
    (ipaddr)->u_addr.addr = ((u32_t)((d) & 0xff) << 24) | \
                            ((u32_t)((c) & 0xff) << 16) | \
                            ((u32_t)((b) & 0xff) << 8)  | \
                            (u32_t)((a) & 0xff)

#define ip_addr_isany(ipaddr) ((ipaddr) == NULL || (ipaddr)->u_addr.addr == 0)

// 网络接口结构（简化占位）
struct netif {
    void *state;  // 指向 wireguard_device
    // 其他字段在鸿蒙适配中不需要
};

// UDP 控制块占位
struct udp_pcb {
    int dummy;
};

// 获取当前时间（毫秒）
// 实际实现在 wireguard_platform_harmony.cpp 中
u32_t sys_now(void);

#ifdef __cplusplus
}
#endif

#endif // LWIP_COMPAT_H
