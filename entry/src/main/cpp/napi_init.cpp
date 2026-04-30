#include "napi/native_api.h"
#include "tunnel/packet_io.h"
#include "tunnel/udp_socket.h"
#include "wireguard/wireguardif_harmony.h"
#include "utils/base64.h"
#include "utils/logger.h"
#include <string>
#include <vector>
#include <arpa/inet.h>

static int32_t g_tunnelFd = -1;

static std::string GetStringFromValueUtf8(napi_env env, napi_value value) {
    std::string result;
    char str[1024] = {0};
    size_t length = 0;
    napi_get_value_string_utf8(env, value, str, sizeof(str), &length);
    if (length > 0) result.append(str, length);
    return result;
}

static bool GetNamedStringProperty(napi_env env, napi_value obj, const char *name, std::string &out) {
    napi_value val;
    napi_status status = napi_get_named_property(env, obj, name, &val);
    if (status != napi_ok) return false;
    out = GetStringFromValueUtf8(env, val);
    return !out.empty();
}

// NAPI: 创建 UDP socket 并连接
static napi_value UdpConnect(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string ipAddr = GetStringFromValueUtf8(env, args[0]);
    int32_t port = 0;
    napi_get_value_int32(env, args[1], &port);

    WG_LOGI("UdpConnect: ip=%{public}s, port=%{public}d", ipAddr.c_str(), port);
    g_tunnelFd = CreateUdpSocket(ipAddr, static_cast<uint16_t>(port));

    napi_value result;
    napi_create_int32(env, g_tunnelFd, &result);
    return result;
}

// NAPI: 启动 VPN（含 WireGuard 初始化）
static napi_value StartVpn(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t tunFd = -1;
    int32_t socketFd = -1;
    napi_get_value_int32(env, args[0], &tunFd);
    if (argc > 1) napi_get_value_int32(env, args[1], &socketFd);

    WG_LOGI("StartVpn: tunFd=%{public}d, socketFd=%{public}d", tunFd, socketFd);
    if (socketFd < 0 && g_tunnelFd >= 0) socketFd = g_tunnelFd;

    // 如果有 config 参数，解析并初始化 WireGuard
    if (argc > 2 && args[2] != nullptr) {
        std::string privateKeyB64, peerPubKeyB64, presharedKeyB64;
        std::string endpointIp;
        int32_t endpointPort = 51820;
        int32_t keepalive = 25;

        napi_value config = args[2];
        GetNamedStringProperty(env, config, "privateKey", privateKeyB64);
        GetNamedStringProperty(env, config, "peerPublicKey", peerPubKeyB64);
        GetNamedStringProperty(env, config, "presharedKey", presharedKeyB64);
        GetNamedStringProperty(env, config, "endpointIp", endpointIp);

        napi_value val;
        if (napi_get_named_property(env, config, "endpointPort", &val) == napi_ok) {
            napi_get_value_int32(env, val, &endpointPort);
        }
        if (napi_get_named_property(env, config, "keepalive", &val) == napi_ok) {
            napi_get_value_int32(env, val, &keepalive);
        }

        // Base64 解码密钥
        uint8_t privateKey[32] = {0};
        uint8_t peerPubKey[32] = {0};
        uint8_t presharedKey[32] = {0};
        size_t keyLen = 32;

        Base64Decode(privateKeyB64.c_str(), privateKey, &keyLen);
        keyLen = 32;
        Base64Decode(peerPubKeyB64.c_str(), peerPubKey, &keyLen);

        // 初始化 WireGuard 设备
        if (!wg_device_init(privateKey)) {
            WG_LOGE("Failed to init WireGuard device");
            napi_value result; napi_create_int32(env, -1, &result); return result;
        }

        // 添加 Peer
        struct wireguard_peer *peer = wg_add_peer(peerPubKey, presharedKeyB64.empty() ? nullptr : presharedKey);
        if (!peer) {
            WG_LOGE("Failed to add peer");
            napi_value result; napi_create_int32(env, -1, &result); return result;
        }

        // 设置 Endpoint
        uint32_t ip = inet_addr(endpointIp.c_str());
        wg_set_peer_endpoint(peer, ip, static_cast<uint16_t>(endpointPort));
        wg_set_peer_keepalive(peer, static_cast<uint16_t>(keepalive));

        WG_LOGI("WireGuard configured, endpoint=%{public}s:%{public}d", endpointIp.c_str(), endpointPort);
    }

    int32_t ret = StartPacketIO(tunFd, socketFd);

    napi_value result;
    napi_create_int32(env, ret, &result);
    return result;
}

// NAPI: 停止 VPN
static napi_value StopVpn(napi_env env, napi_callback_info info) {
    WG_LOGI("StopVpn called");
    StopPacketIO();
    CloseUdpSocket(g_tunnelFd);
    g_tunnelFd = -1;
    napi_value result; napi_create_int32(env, 0, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "startVpn", nullptr, StartVpn, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopVpn", nullptr, StopVpn, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "udpConnect", nullptr, UdpConnect, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1, .nm_flags = 0, .nm_filename = nullptr,
    .nm_register_func = Init, .nm_modname = "entry",
    .nm_priv = ((void*)0), .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    WG_LOGI("WireGuard Native module registered");
    napi_module_register(&demoModule);
}
