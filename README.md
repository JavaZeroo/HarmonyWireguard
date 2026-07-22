# HarmonyWireguard

HarmonyWireguard 是面向 HarmonyOS NEXT 的原生 WireGuard 客户端技术预览版。项目使用 ArkTS、ArkUI、
`VpnExtensionAbility` 与原生 C/C++ 隧道实现，目标系统为 HarmonyOS 6.0.2（API 22）。

> [!WARNING]
> v1.0.0 是技术预览版本，尚未完成独立密码学与安全审计。请仅在测试环境和可控网络中使用，
> 不要把它作为生产环境、企业网络或高敏感数据的安全边界。

## 功能

- 导入、编辑和管理 WireGuard 配置。
- 通过 HarmonyOS VPN Extension 建立系统 VPN 隧道。
- 展示连接状态、握手时间、流量统计与诊断结果。
- 适配手机竖屏、手机横屏、平板与 2-in-1 窗口。
- 提供浅色、深色、紧凑模式和隐私窗口支持。

## 开发环境

- HarmonyOS 6.0.2 SDK（API 22）
- DevEco Studio 6.0.2 Release
- Hvigor 6.22.x
- 支持 VPN Extension 的 HarmonyOS NEXT 真机

## 构建

```powershell
ohpm install
hvigorw.bat --mode module -p product=default -p module=entry@default `
  -p buildMode=debug assembleHap --no-daemon
```

公开仓库中的 `build-profile.json5` 不包含任何签名口令或证书路径。请在本机 DevEco Studio 中配置自己的
调试或发布签名，且不要提交证书、Profile、密钥库或口令。

## 测试

项目的 `entry/src/ohosTest` 包含配置解析、状态负载与核心工具测试。涉及 VPN Extension 的完整流程需要在
真机上验证，包括授权、连接、断开、旋转窗口、后台恢复和网络切换。

## 隐私与安全

配置与密钥仅在应用沙箱内处理，不会上传到项目维护者的服务器。当前预览版仍有待完成的安全加固事项，
请阅读 [隐私说明](PRIVACY.md) 和 [安全策略](SECURITY.md)。

## 已知限制

- 当前只完整支持 IPv4 Endpoint；IPv6 Endpoint、Address 与 DNS 尚未完整支持。
- 尚未完成独立协议实现审计、压力测试与长期重连验证。
- 公共源码不附带可复用的发布签名材料。

## 许可证与商标

项目自有代码使用 [MIT License](LICENSE)。第三方组件保留各自许可证与版权声明，详见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

WireGuard 是 Jason A. Donenfeld 的注册商标。本项目是独立社区项目，与 WireGuard 项目及其作者无隶属或
背书关系。
