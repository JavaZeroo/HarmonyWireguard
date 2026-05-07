# HarmonyOS WireGuard 客户端功能设计

## 1. 功能定位

本客户端定位为：

> 面向 HarmonyOS 手机、平板、PC 多设备的 WireGuard 隧道管理与连接工具，提供配置导入、隧道连接、状态监控、诊断、安全存储、多端适配和自动化连接能力。

当前假设核心功能已具备：

```text
- WireGuard 隧道创建
- 启动连接
- 断开连接
- 基础配置编辑
- 基础状态展示
```

后续功能应围绕以下方向增强：

```text
- 配置导入更完整
- 连接状态更可信
- 诊断能力更强
- 安全保护更严格
- 多设备体验更一致
- 自动连接策略更实用
```

---

## 2. 参考现有客户端能力

### 2.1 官方 WireGuard Android 客户端

官方 Android 客户端是一个 WireGuard GUI，优先使用内核实现，无法使用时回退到非 root 用户态实现。这个对 HarmonyOS 很有参考价值：如果系统 VPN/TUN 能力限制较多，客户端架构应预留“系统 VPN 能力 + 用户态 WireGuard 引擎”的抽象层。([git.zx2c4.com][1])

Android 端常见能力包括：

```text
- 添加隧道
- 导入 .conf
- 扫描二维码导入
- 从二维码图片导入
- 启用 / 禁用隧道
- 编辑配置
- 导出配置
```

官方 Android 客户端曾加入“从本地二维码图片导入隧道”的能力，因为用户收到二维码图片后，不一定方便用相机扫描外部屏幕。这个功能在 HarmonyOS 上也很值得做。([git.zx2c4.com][2])

---

### 2.2 官方 WireGuard Windows 客户端

Windows 客户端有几个非常重要的设计点：

```text
- 隧道可以作为系统服务安装
- 配置文件可被加密保存
- UI 可导出配置
- 支持诊断日志
- 可通过命令行安装、卸载、更新、导出日志
```

官方 Windows 文档中，隧道服务会创建 `WireGuardTunnel$配置名` 服务；配置可使用 `.conf.dpapi` 形式加密；运行态可以通过 `wg show` 查看 public key、endpoint、allowed ips、latest handshake、transfer 等信息。([git.zx2c4.com][3])

对 HarmonyOS 来说，虽然不一定能完全复刻 Windows 服务模型，但可以借鉴：

```text
- 后台 VPN Extension / 后台任务
- 安全配置存储
- 诊断日志 ring buffer
- 导出诊断报告
- 后台连接状态恢复
```

---

### 2.3 iOS / macOS WireGuard 客户端

Apple 平台的 WireGuard 客户端一个关键能力是 **On-Demand Activation**，也就是按网络条件自动启用隧道。WireGuard Apple 代码里有相关逻辑：启用 On-Demand 时需要确保 tunnel provider 本身处于 enabled 状态，否则系统不会根据规则自动启停。([git.zx2c4.com][4])

对 HarmonyOS 客户端来说，对应能力是：

```text
- 按 WLAN SSID 自动连接
- 按蜂窝网络自动连接
- 按以太网自动连接
- 离开指定网络后自动连接
- 进入家庭/公司网络后自动断开
- 系统重启后恢复连接策略
```

---

### 2.4 第三方增强型客户端

第三方 Android 客户端 WG Tunnel 提供了更完整的高级功能，例如 `.conf`、ZIP、手动、二维码导入；按 Wi-Fi SSID、以太网、移动数据自动连接；Split Tunneling；Always-On VPN；快捷开关；Intent 自动化；重启后恢复；HTTP/SOCKS5 代理；Kill Switch；动态 DNS；高级监控等。([GitHub][5])

这类功能不一定 Phase 1 全部实现，但很适合作为 HarmonyOS 版本的中长期目标。

---

## 3. 功能总览

建议按优先级分成 5 层：

```text
P0：核心连接能力
P1：配置管理能力
P2：状态监控与诊断能力
P3：安全与隐私能力
P4：自动化与高级网络能力
```

---

# P0：核心连接能力

## 4. 隧道连接管理

### 4.1 启动隧道

必须支持：

```text
- 选择一个配置并启动
- 启动前校验配置
- 启动时显示 connecting 状态
- 启动成功后显示 connected 状态
- 启动失败后显示明确错误
```

状态模型建议：

```typescript
type TunnelStatus =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'disconnecting'
  | 'failed'
  | 'permissionRequired'
```

### 4.2 断开隧道

必须支持：

```text
- 当前隧道断开
- 断开中状态
- 断开失败提示
- 断开后恢复路由 / DNS
```

### 4.3 单隧道激活策略

建议初期只允许一个隧道处于 active 状态。

```text
- 启动 A 隧道时，如果 B 隧道已连接，先断开 B
- 用户切换隧道时给出提示
- 后续可扩展多 Peer，但不建议多个独立 VPN 同时激活
```

### 4.4 VPN 权限处理

HarmonyOS 客户端必须有清晰的权限状态：

```text
- 未授权
- 已授权
- 权限被系统撤销
- 系统 VPN 正被其他 App 占用
- VPN Extension 启动失败
```

UI 上不要只显示“连接失败”，应显示：

```text
需要 VPN 权限
当前系统需要授权此应用创建 VPN 连接。
[去授权]
```

---

# P1：配置管理能力

## 5. 配置导入

这是 WireGuard 客户端最重要的体验之一。

### 5.1 必须支持的导入方式

```text
- 扫描二维码导入
- 从本地二维码图片导入
- 从 .conf 文件导入
- 从剪贴板导入
- 手动创建
```

官方 Android 端已经支持二维码导入，并且加入了“从二维码图片文件导入”的能力，这对家庭用户、跨设备发送配置非常实用。([git.zx2c4.com][2])

### 5.2 建议支持的批量导入

```text
- 从 ZIP 导入多个 .conf
- 从文件夹批量导入
- 重名配置自动处理
- 导入前预览
```

第三方客户端常见支持 `.conf`、ZIP、手动、二维码等多种导入方式。([GitHub][5])

### 5.3 导入预览

导入后不要直接保存，建议进入预览页：

```text
- 配置名称
- 本地地址 Address
- DNS
- Peer PublicKey
- Endpoint
- AllowedIPs
- PersistentKeepalive
- MTU
- 是否全局代理
- 是否包含 IPv6
- 是否包含私钥
```

如果 `AllowedIPs = 0.0.0.0/0, ::/0`，应提示：

```text
这是全局代理配置，所有 IPv4/IPv6 流量都会进入 VPN。
```

---

## 6. 配置编辑

### 6.1 Interface 配置

WireGuard 原生配置中 Interface 侧建议支持：

```text
- PrivateKey
- Address
- DNS
- MTU
- ListenPort，可选
```

### 6.2 Peer 配置

Peer 侧建议支持：

```text
- PublicKey
- PresharedKey，可选
- Endpoint
- AllowedIPs
- PersistentKeepalive
```

WireGuard 跨平台接口定义中，peer 相关字段包括 `preshared_key`、`endpoint`、`persistent_keepalive_interval`、`allowed_ip` 等，这些都应能被配置模型表达。([WireGuard][6])

### 6.3 Endpoint 输入优化

不要只给一个文本框，建议拆分为：

```text
服务器地址 Host
端口 Port
```

最终保存时再组合为：

```text
example.com:51820
192.168.3.1:51820
[2001:db8::1]:51820
```

### 6.4 AllowedIPs 路由模式

建议不要让用户一上来直接填 CIDR，而是做模式选择：

```text
路由模式：
- 全局代理
- 仅访问内网
- 自定义路由
```

对应关系：

| 模式        | AllowedIPs                                  |
| --------- | ------------------------------------------- |
| 全局代理      | `0.0.0.0/0, ::/0`                           |
| 仅 IPv4 全局 | `0.0.0.0/0`                                 |
| 仅访问内网     | `192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12` |
| 自定义       | 用户手动添加 CIDR                                 |

### 6.5 配置校验

保存前必须校验：

```text
- PrivateKey 是否为合法 WireGuard key
- PublicKey 是否为合法 WireGuard key
- PresharedKey 是否为合法 WireGuard key
- Address 是否为合法 CIDR
- AllowedIPs 是否为合法 CIDR
- Endpoint 是否包含端口
- Port 是否在 1–65535
- DNS 是否为合法 IP
- MTU 是否在合理范围
- 是否缺少 Peer
```

---

## 7. 配置导出

### 7.1 单配置导出

支持：

```text
- 导出为 .conf
- 复制为文本
- 生成二维码
- 保存二维码图片
```

### 7.2 批量导出

支持：

```text
- 批量导出 ZIP
- 批量导出时可选择是否包含私钥
```

### 7.3 敏感导出确认

导出包含 `PrivateKey` 的配置时必须二次确认：

```text
导出的配置包含私钥。任何获得此文件的人都可以使用该 VPN 身份。
[取消] [继续导出]
```

Windows 客户端文档中也强调配置可以导出，且本地配置可以加密存储，这说明“安全保存 + 受控导出”是成熟客户端的基础能力。([git.zx2c4.com][3])

---

# P2：状态监控与诊断能力

## 8. 运行态状态展示

WireGuard 可获取的关键运行态字段包括：

```text
- rx_bytes
- tx_bytes
- last_handshake_time_sec
- last_handshake_time_nsec
```

这些字段在 WireGuard 跨平台接口中有定义，应作为状态页的基础数据源。([WireGuard][6])

### 8.1 首页展示

首页建议显示：

```text
- 当前连接状态
- 当前隧道名称
- 最近握手时间
- 接收流量
- 发送流量
- Endpoint
```

### 8.2 详情页展示

详情页建议显示：

```text
- Interface PublicKey
- 本地 Address
- Peer PublicKey
- Endpoint
- AllowedIPs
- DNS
- MTU
- 最近握手
- 接收总量
- 发送总量
- 当前接收速率
- 当前发送速率
```

### 8.3 不建议显示“真实在线”

WireGuard 是 UDP 协议，不存在传统 TCP 连接意义上的“持续在线连接”。更准确的表达是：

```text
- 最近握手：15 秒前
- 最近有流量：刚刚
- 接收 / 发送字节仍在变化
```

不要用：

```text
- 用户在线
- 服务器在线
- 连接 100% 正常
```

---

## 9. 诊断功能

### 9.1 基础诊断

建议实现：

```text
- 配置语法检查
- Endpoint DNS 解析检查
- Endpoint UDP 可达性提示
- 最近握手检查
- 是否只有发送无接收
- DNS 是否生效
- 默认路由是否进入 VPN
- IPv6 是否泄漏
- 本地网段是否仍可访问
```

### 9.2 常见问题识别

可以做规则化诊断：

| 现象      | 可能原因                       | UI 提示          |
| ------- | -------------------------- | -------------- |
| 有发送无接收  | 服务端未响应 / 防火墙 / Endpoint 错误 | “没有收到对端响应”     |
| 有握手无流量  | AllowedIPs / 路由 / DNS 问题   | “握手成功，但路由可能异常” |
| 无握手     | Key / Endpoint / 网络问题      | “未完成握手”        |
| DNS 失败  | DNS 未设置或被拦截                | “VPN DNS 不可用”  |
| 内网不可达   | AllowedIPs 未包含内网段          | “路由未包含目标网段”    |
| IPv6 直连 | 未配置 `::/0` 或未禁用 IPv6       | “可能存在 IPv6 泄漏” |

### 9.3 诊断报告导出

建议支持：

```text
- 导出诊断日志
- 导出当前运行状态
- 导出系统网络信息摘要
- 自动隐藏私钥
- 自动隐藏完整公网 IP，可选
```

Windows 客户端提供诊断日志，并支持通过命令导出或 tail 日志，这说明诊断日志是桌面级 WireGuard 客户端的重要能力。([git.zx2c4.com][3])

---

## 10. 日志功能

### 10.1 日志等级

```text
- Error
- Warning
- Info
- Debug
```

### 10.2 日志内容

建议记录：

```text
- App 启动
- VPN Extension 启动
- 隧道启动
- 隧道停止
- 配置导入
- 配置保存
- 配置解析失败
- DNS 解析失败
- 握手超时
- 网络切换
- 自动重连
```

### 10.3 日志隐私

日志中不要记录：

```text
- PrivateKey
- PresharedKey
- 完整配置原文
```

PublicKey 可以展示，但建议允许一键脱敏。

---

# P3：安全与隐私能力

## 11. 密钥保护

### 11.1 私钥存储

要求：

```text
- PrivateKey 不明文存储在普通 preferences
- 使用系统安全存储能力
- UI 层只保存 privateKeyRef
- 导出时临时读取
```

Windows 客户端的企业文档中提到 `.conf.dpapi` 加密配置，并限制普通用户读取未加密配置，这个设计对 HarmonyOS 有直接参考意义。([git.zx2c4.com][3])

### 11.2 私钥显示

默认：

```text
PrivateKey：已设置
```

点击显示时：

```text
- 二次确认
- 可设置 30 秒后自动隐藏
- 禁止截图，可选
- 页面离开自动隐藏
```

### 11.3 剪贴板保护

建议：

```text
- 复制私钥后 30 秒自动清空剪贴板
- 粘贴配置后提示是否清除剪贴板
- 从剪贴板读取前提示用户
```

---

## 12. Kill Switch / 防泄漏

### 12.1 基础防泄漏

建议提供开关：

```text
- VPN 断开时阻止流量
- 禁止 IPv6 泄漏
- DNS 仅走 VPN
- 排除本地网络
```

### 12.2 风险提示

例如：

```text
当前配置只代理 IPv4，IPv6 流量可能不会经过 VPN。
[修复为全局 IPv4 + IPv6] [忽略]
```

WG Tunnel 这类增强型客户端已经提供 Lockdown / Kill Switch 类能力，可作为高级功能参考。([GitHub][5])

---

# P4：自动化与高级网络能力

## 13. 自动连接

### 13.1 基础自动连接

```text
- App 启动后自动连接上次隧道
- 系统重启后恢复上次隧道
- 网络切换后自动重连
- 连接失败后指数退避重试
```

### 13.2 按网络自动连接

```text
- 连接指定 WLAN 时自动连接
- 连接指定 WLAN 时自动断开
- 使用移动数据时自动连接
- 使用以太网时自动连接
- 离开可信网络时自动连接
```

Apple 端的 On-Demand 逻辑和第三方 Android 客户端的 Auto-Tunneling 都说明“按网络条件自动启停”是成熟移动端 VPN 客户端的重要能力。([git.zx2c4.com][4])

### 13.3 可信网络

```text
可信网络：
- 家庭 Wi-Fi
- 公司 Wi-Fi
- 指定 SSID
- 指定网关
- 指定 DNS 后缀，可选
```

示例策略：

```text
当连接到 家庭WiFi 时：
- 自动断开公司 VPN

当离开 家庭WiFi 时：
- 自动连接家庭 WireGuard
```

---

## 14. 分应用代理 / Split Tunneling

### 14.1 分应用策略

如果 HarmonyOS VPN 能力支持，建议实现：

```text
- 所有应用走 VPN
- 仅选定应用走 VPN
- 选定应用不走 VPN
```

### 14.2 分路由策略

```text
- 全局代理
- 仅内网路由
- 自定义 CIDR
- 排除本地 LAN
```

WG Tunnel 支持 Split Tunneling，可作为高级功能参考。([GitHub][5])

---

## 15. DNS 高级功能

建议支持：

```text
- 使用配置内 DNS
- 自动使用系统 DNS
- 自定义 DNS
- DNS 泄漏检测
- Endpoint 域名重新解析
- 动态 DNS 更新后自动重连
```

第三方客户端中已有动态 DNS 处理、高级 DNS、DoH 解析 endpoint 等能力，这些适合作为高级路线图。([GitHub][5])

---

## 16. 快捷控制

### 16.1 移动端快捷入口

```text
- 控制中心快捷开关
- 桌面快捷方式
- 长按 App 图标快速连接
- 通知栏显示当前 VPN 状态
- 通知栏一键断开
```

### 16.2 PC 端快捷入口

```text
- 托盘图标
- 快速切换隧道
- 开机自启
- 最小化到托盘
- 快捷键连接 / 断开
```

Windows 客户端会在 manager service 运行时启动系统托盘 UI，这个交互模型适合 HarmonyOS PC 形态参考。([git.zx2c4.com][3])

---

## 17. 多设备同步，可选

如果你后续想做 HarmonyOS 生态体验，可以考虑：

```text
- 手机扫码导入后同步到平板
- 平板编辑配置后同步到 PC
- 多设备共享配置但不共享私钥
- 每台设备独立生成 PrivateKey
- 同一个服务端 Peer 管理多个设备
```

注意：**不建议默认多设备共享同一个 PrivateKey**。更合理的是每台设备一个 Peer。

---

# 18. 功能优先级建议

## 18.1 第一阶段：补齐成熟客户端基础体验

```text
P0-1 启动 / 断开 / 切换隧道
P0-2 VPN 权限处理
P1-1 扫码导入
P1-2 .conf 文件导入
P1-3 剪贴板导入
P1-4 手动编辑
P1-5 导入预览
P2-1 最近握手
P2-2 接收 / 发送流量
P3-1 私钥安全存储
P3-2 敏感导出确认
```

## 18.2 第二阶段：增强可用性

```text
P1-6 ZIP 批量导入
P1-7 二维码图片导入
P1-8 配置导出 .conf
P1-9 生成二维码
P2-3 诊断页
P2-4 日志页
P2-5 导出诊断报告
P3-3 剪贴板保护
P3-4 IPv6 泄漏提示
```

## 18.3 第三阶段：高级 VPN 客户端能力

```text
P4-1 自动重连
P4-2 按 WLAN SSID 自动连接
P4-3 重启后恢复连接
P4-4 Split Tunneling
P4-5 Kill Switch
P4-6 动态 DNS 更新
P4-7 快捷开关
P4-8 多设备配置同步
```

---

# 19. 最终功能清单

## 必须实现

```text
- 配置列表
- 配置详情
- 新增配置
- 编辑配置
- 删除配置
- 扫码导入
- .conf 导入
- 剪贴板导入
- 启动隧道
- 断开隧道
- 切换隧道
- VPN 权限处理
- PrivateKey 安全存储
- PublicKey / PrivateKey 校验
- Endpoint 校验
- AllowedIPs 校验
- Address 校验
- DNS 校验
- 当前连接状态
- 最近握手
- 接收 / 发送流量
- 错误提示
```

## 强烈建议实现

```text
- 导入预览
- 二维码图片导入
- ZIP 批量导入
- 导出 .conf
- 生成二维码
- 路由模式选择
- DNS 设置
- MTU 设置
- PersistentKeepalive 设置
- 配置复制
- 配置重命名
- 诊断页
- 日志页
- 导出诊断报告
- 自动重连
- 网络切换后恢复
- IPv6 泄漏提示
- 私钥查看二次确认
- 剪贴板自动清理
```

## 高级功能

```text
- 按 WLAN SSID 自动连接
- 按移动数据自动连接
- 按以太网自动连接
- 可信网络规则
- Split Tunneling
- Kill Switch
- Always-On VPN
- 快捷开关
- 桌面快捷方式
- 多设备配置同步
- 动态 DNS 检测
- Endpoint DoH 解析
- 代理入口 HTTP / SOCKS5
- 自动化 Intent / Shortcut
```

---

## 20. 我建议你下一步的落地方式

你现在核心能力已经有了，下一步不要先做太多高级功能。建议直接按这个顺序排：

```text
1. 配置导入体系
   - 扫码
   - 文件
   - 剪贴板
   - 二维码图片

2. 配置安全体系
   - 私钥安全存储
   - 导出确认
   - 剪贴板保护

3. 状态可信体系
   - 最近握手
   - rx / tx
   - endpoint
   - 当前错误

4. 诊断体系
   - 无握手
   - 有握手无流量
   - DNS 异常
   - AllowedIPs 异常
   - IPv6 泄漏

5. 自动化体系
   - 自动重连
   - 网络切换恢复
   - 按 WLAN 规则连接
```

最关键的一点：**不要把它做成“能填 WireGuard 配置的工具”，而是做成“能解释 WireGuard 状态、帮助用户判断为什么不能用的客户端”。** 这会明显拉开和普通移植版客户端的差距。

[1]: https://git.zx2c4.com/wireguard-android/about/ "wireguard-android - Android GUI for WireGuard"
[2]: https://git.zx2c4.com/wireguard-android/commit/?id=0bd39309c8ba839191684d5d34c247c0af7b42aa "ui: allow importing tunnel from an QR image stored on the device - wireguard-android - Android GUI for WireGuard"
[3]: https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md "wireguard-windows - WireGuard client for Windows"
[4]: https://git.zx2c4.com/wireguard-apple/commit/?id=c1fe8b01625945dd86e2982812288f524e3f537f "UI: When setting on-demand, enable the tunnel if required - wireguard-apple - iOS and macOS apps for WireGuard"
[5]: https://github.com/wgtunnel/wgtunnel "GitHub - wgtunnel/android: A FOSS WireGuard & AmneziaWG Android client with auto-tunneling, lockdown & proxying. · GitHub"
[6]: https://www.wireguard.com/xplatform/ "Cross-platform Interface - WireGuard"
