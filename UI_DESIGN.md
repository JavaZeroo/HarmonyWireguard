# HarmonyOS WireGuard 客户端 UI 设计方案

> 版本：v1.0  
> 适用范围：HarmonyOS / HarmonyOS NEXT 风格的 WireGuard VPN 客户端 UI 与交互设计  
> 目标设备：手机、平板、折叠屏、PC/大屏设备  
> 技术栈建议：ArkTS + ArkUI + Stage 模型 + 响应式/自适应布局  
> 说明：本文档聚焦 UI、交互、信息架构和前端数据模型。底层 VPN 能力、系统权限、网络扩展 Ability/API 名称需以实际 HarmonyOS SDK 和设备开放能力为准。

---

## 1. 设计目标

### 1.1 产品定位

本应用是一个面向 HarmonyOS 多设备场景的 WireGuard VPN 客户端，用于在手机、平板、电脑等设备上管理和连接 WireGuard 隧道。

核心目标：

1. **快速连接**
   - 用户打开应用后能立即看到当前连接状态。
   - 一键连接 / 断开指定隧道。
   - 连接失败时提供明确原因和修复建议。

2. **配置导入优先**
   - 优先支持二维码、`.conf` 文件、剪贴板导入。
   - 手动编辑作为高级入口，不作为主流程。
   - 导入后提供解析预览，避免用户误保存错误配置。

3. **符合 WireGuard 心智模型**
   - 明确区分 `Interface` 和 `Peer`。
   - 重点解释 `AllowedIPs` 的路由含义。
   - 将全局代理、仅访问内网、自定义路由作为用户可理解的模式。

4. **适配 HarmonyOS 多端体验**
   - 手机使用单栏连接控制台。
   - 平板/折叠屏使用双栏布局。
   - PC/大屏使用三栏布局，展示配置、详情、诊断日志。
   - 使用卡片、分栏、响应式布局和系统化资源文件。

5. **安全优先**
   - 私钥默认不可见。
   - 查看、复制、导出敏感配置需要二次确认。
   - 敏感字段不进入普通日志。
   - 配置导出时明确提示包含私钥。

---

## 2. 设计原则

### 2.1 HarmonyOS 侧设计原则

| 原则 | 应用到本项目 |
|---|---|
| 一次开发，多端部署 | 页面使用断点和自适应布局，不按设备类型硬编码 |
| 卡片化信息组织 | 当前连接、配置、诊断、流量均使用卡片承载 |
| 主次分明 | 首页优先展示当前连接，而不是把配置列表作为唯一主体 |
| 轻量动效 | 连接、握手、刷新、页面切换使用克制动效 |
| 系统资源化 | 颜色、字体、间距、字符串全部资源化 |
| 多端一致，布局差异 | 手机、平板、PC 操作一致，但布局密度不同 |

### 2.2 WireGuard 侧设计原则

| WireGuard 概念 | UI 表达方式 |
|---|---|
| `PrivateKey` | 默认隐藏，仅显示“已设置”，查看需确认 |
| `PublicKey` | 可复制，可折叠显示 |
| `Endpoint` | 拆分为主机名/IP + 端口 |
| `AllowedIPs` | 抽象成“全局代理 / 仅访问内网 / 自定义路由” |
| `PersistentKeepalive` | 默认推荐 25s，可关闭 |
| `PresharedKey` | 可选增强安全项，默认折叠 |
| `rx_bytes` / `tx_bytes` | 展示为接收/发送流量 |
| `last_handshake_time` | 展示为“最近握手：x 秒前” |
| 连接失败 | 诊断 Endpoint、DNS、权限、路由、握手状态 |

---

## 3. 用户场景

### 3.1 典型用户场景

| 场景 | 用户目标 | UI 支持 |
|---|---|---|
| 首次使用 | 导入 WireGuard 配置并连接 | 添加配置页 + 导入预览 + 一键连接 |
| 日常连接 | 快速连接公司/家庭网络 | 首页连接控制台 |
| 多配置切换 | 在公司、家庭、服务器之间切换 | 配置列表 + 当前连接状态 |
| 连接失败 | 判断是 DNS、Endpoint、路由还是权限问题 | 连接详情页 + 诊断检查 |
| 安全管理 | 避免私钥泄漏 | 私钥隐藏、查看确认、导出确认 |
| 平板使用 | 一边看配置，一边看状态 | 双栏布局 |
| PC 使用 | 管理多个配置并查看日志 | 三栏布局 |

### 3.2 核心用户路径

```text
首次使用：
打开应用
→ 添加配置
→ 扫描二维码 / 导入文件 / 剪贴板导入
→ 配置解析预览
→ 保存
→ 连接
→ 查看连接状态

日常使用：
打开应用
→ 查看当前连接状态
→ 点击连接 / 断开
→ 必要时进入详情查看流量和握手

故障排查：
连接失败
→ 进入连接详情
→ 查看诊断检查项
→ 查看最近错误
→ 导出诊断报告
```

---

## 4. 信息架构

```text
WireGuard Client
├── 连接中心 Home
│   ├── 当前连接卡片
│   ├── 快速诊断摘要
│   ├── 配置列表
│   └── 添加配置入口
├── 添加配置 Import
│   ├── 扫描二维码
│   ├── 从文件导入
│   ├── 从剪贴板导入
│   └── 手动创建
├── 导入预览 ConfigPreview
│   ├── 解析结果
│   ├── 风险提示
│   ├── 路由模式识别
│   └── 保存 / 编辑
├── 配置编辑 ConfigEditor
│   ├── 显示信息
│   ├── Interface 本机接口
│   ├── Peer 对端服务器
│   ├── 路由与 DNS
│   └── 高级设置
├── 隧道详情 TunnelDetail
│   ├── 状态摘要
│   ├── 实时流量
│   ├── 路由信息
│   ├── 诊断检查
│   └── 运行日志
└── 设置 Settings
    ├── 自动连接
    ├── 网络变化重连
    ├── 隐私与安全
    ├── 日志级别
    ├── 外观
    └── 关于
```

---

## 5. 页面清单

| 页面文件 | 页面名称 | 说明 |
|---|---|---|
| `Index.ets` | 连接中心 | 首页，展示当前连接、配置列表、快速诊断 |
| `ImportConfigPage.ets` | 添加配置 | 二维码、文件、剪贴板、手动创建 |
| `ConfigPreviewPage.ets` | 导入预览 | 解析 WireGuard 配置并提示风险 |
| `ConfigEditPage.ets` | 配置编辑 | 编辑 Interface、Peer、路由、DNS、高级项 |
| `TunnelDetailPage.ets` | 隧道详情 | 展示状态、流量、握手、诊断和日志 |
| `SettingsPage.ets` | 设置 | 全局行为、安全和外观 |
| `AboutPage.ets` | 关于 | 版本、开源协议、隐私说明 |

---

## 6. 多端布局策略

### 6.1 断点定义

| 断点 | 宽度范围 | 推荐布局 |
|---|---:|---|
| Compact | `< 600vp` | 手机单栏 |
| Medium | `600vp - 840vp` | 平板 / 折叠屏双栏 |
| Expanded | `> 840vp` | PC / 大屏三栏或双栏 + 侧边栏 |

### 6.2 手机单栏布局

```text
┌─────────────────────────────┐
│ Header                      │
├─────────────────────────────┤
│ ConnectionHeroCard          │
│ DiagnosticSummaryCard       │
│ TunnelList                  │
│ AddConfigButton / FAB       │
└─────────────────────────────┘
```

特点：

- 主操作按钮足够大。
- 诊断信息只显示摘要。
- 配置项纵向列表。
- 详情和编辑使用新页面进入。

### 6.3 平板 / 折叠屏双栏布局

```text
┌───────────────┬─────────────────────────┐
│ TunnelList    │ TunnelDetail             │
│ Add / Search  │ Status / Traffic / Route │
│ Settings      │ Diagnostics              │
└───────────────┴─────────────────────────┘
```

特点：

- 左侧固定配置列表。
- 右侧显示当前选中配置详情。
- 编辑页可作为右侧页面或半屏弹层出现。

### 6.4 PC / 大屏三栏布局

```text
┌──────────┬───────────────────┬─────────────────┐
│ Sidebar  │ TunnelDetail       │ Diagnostics     │
│ Configs  │ Status / Traffic   │ Logs / Tests    │
│ Settings │ Route / Actions    │ Export Report   │
└──────────┴───────────────────┴─────────────────┘
```

特点：

- 侧边栏显示配置和设置入口。
- 中间为当前连接详情。
- 右侧常驻诊断和日志。
- 支持键盘操作和更高信息密度。

---

## 7. 设计系统

### 7.1 色彩系统

#### 基础色

| Token | 值 | 用途 |
|---|---|---|
| `primary` | `#007DFF` | 主按钮、强调、连接中 |
| `primary_dark` | `#0056CC` | 主按钮按下态 |
| `success` | `#00B386` | 已连接、正常 |
| `warning` | `#FF8800` | 警告、风险提示 |
| `danger` | `#FA2C2C` | 失败、断开、删除 |
| `info` | `#007DFF` | 信息提示 |

#### 浅色模式

| Token | 值 | 用途 |
|---|---|---|
| `background` | `#F1F3F5` | 页面背景 |
| `surface` | `#FFFFFF` | 卡片和面板 |
| `surface_subtle` | `#F7F9FA` | 输入框、弱背景 |
| `text_primary` | `#E6000000` | 主文本 |
| `text_secondary` | `#99000000` | 次要文本 |
| `text_tertiary` | `#66000000` | 辅助文本 |
| `divider` | `#1F000000` | 分割线 |

#### 深色模式

| Token | 值 | 用途 |
|---|---|---|
| `background` | `#121212` | 页面背景 |
| `surface` | `#1E1E1E` | 卡片和面板 |
| `surface_subtle` | `#252525` | 输入框、弱背景 |
| `text_primary` | `#E6FFFFFF` | 主文本 |
| `text_secondary` | `#99FFFFFF` | 次要文本 |
| `text_tertiary` | `#66FFFFFF` | 辅助文本 |
| `divider` | `#1FFFFFFF` | 分割线 |

#### 状态背景

| Token | 值 | 用途 |
|---|---|---|
| `success_bg` | `#E8F8F3` | 已连接卡片弱背景 |
| `warning_bg` | `#FFF3E0` | 风险提示弱背景 |
| `danger_bg` | `#FFEBEE` | 失败提示弱背景 |
| `primary_bg` | `#EAF4FF` | 当前连接弱背景 |

### 7.2 间距系统

以 `8vp` 为基础网格。

```typescript
export const SPACING = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48
} as const
```

### 7.3 圆角系统

```typescript
export const RADIUS = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 999
} as const
```

| 组件 | 圆角 |
|---|---:|
| 标签 / Badge | `8vp` |
| 输入框 | `12vp` |
| 列表卡片 | `16vp` |
| 当前连接大卡片 | `24vp` |
| 弹窗 / 底部面板 | `24vp` |
| 状态胶囊 | `999vp` |

### 7.4 字体系统

建议使用系统字体，遵循 HarmonyOS Sans / 系统默认字体策略。

```typescript
export const TYPOGRAPHY = {
  title_lg: { size: 28, weight: FontWeight.Bold },
  title_md: { size: 24, weight: FontWeight.Bold },
  title_sm: { size: 20, weight: FontWeight.Medium },
  body_lg: { size: 18, weight: FontWeight.Regular },
  body_md: { size: 16, weight: FontWeight.Regular },
  body_sm: { size: 14, weight: FontWeight.Regular },
  caption: { size: 12, weight: FontWeight.Regular },
  label: { size: 12, weight: FontWeight.Medium }
} as const
```

### 7.5 阴影与层级

VPN 工具类 App 不建议过度依赖重阴影。建议使用轻阴影 + 背景层级。

```typescript
export const SHADOW = {
  sm: { radius: 4, color: 'rgba(0,0,0,0.06)', offsetY: 2 },
  md: { radius: 8, color: 'rgba(0,0,0,0.10)', offsetY: 4 },
  lg: { radius: 16, color: 'rgba(0,0,0,0.14)', offsetY: 8 }
} as const
```

---

## 8. 图标和视觉语言

### 8.1 图标原则

不建议使用 Emoji 作为正式 UI 图标。Emoji 在不同设备、字体和系统版本上的显示风格不可控。

建议使用统一线性图标或系统 Symbol 风格图标。

| 场景 | 图标建议 |
|---|---|
| 公司内网 | building / briefcase |
| 家庭网络 | home |
| 服务器 | server |
| 全局代理 | globe |
| 仅访问内网 | network / lan |
| 密钥 | key |
| DNS | dns / globe |
| 诊断 | activity / pulse |
| 日志 | document / terminal |
| 设置 | settings |

### 8.2 状态表达

| 状态 | 表达 |
|---|---|
| 已连接 | 绿色圆点 + “已连接” |
| 连接中 | 蓝色圆点 + LoadingProgress |
| 未连接 | 灰色圆点 + “未连接” |
| 失败 | 红色圆点 + 错误摘要 |
| 需要权限 | 橙色提示条 |

---

## 9. 首页：连接中心 `Index.ets`

### 9.1 页面目标

首页不是简单配置列表，而是 **连接控制台**。用户打开应用后应立即知道：

1. 当前是否已连接。
2. 当前连接的是哪个隧道。
3. 最近握手是否正常。
4. 今日/本次接收和发送流量。
5. 连接失败时如何处理。
6. 有哪些可用配置。

### 9.2 手机端布局

```text
┌─────────────────────────────┐
│ WireGuard              设置 │
├─────────────────────────────┤
│                             │
│ ┌─────────────────────────┐ │
│ │ 当前连接                 │ │
│ │ 公司内网                 │ │
│ │ ● 已连接 · 15 秒前握手   │ │
│ │ Endpoint: vpn.example... │ │
│ │ ↓ 1.2GB      ↑ 856MB     │ │
│ │                         │ │
│ │        [ 断开连接 ]       │ │
│ │        [ 查看详情 ]       │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 快速诊断                 │ │
│ │ 延迟 45ms · DNS 正常     │ │
│ │ Endpoint 可达 · MTU 1420 │ │
│ └─────────────────────────┘ │
│                             │
│ 配置                         │
│ ┌─────────────────────────┐ │
│ │ 公司内网        已连接   │ │
│ │ vpn.example.com:51820   │ │
│ │ 全局代理 · Keepalive 25s │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 家庭网络        未连接   │ │
│ │ home.example.com:51820  │ │
│ │ 仅访问内网              │ │
│ └─────────────────────────┘ │
│                             │
│          [ 添加配置 ]        │
└─────────────────────────────┘
```

### 9.3 组件说明

#### `ConnectionHeroCard`

| 属性 | 说明 |
|---|---|
| `status` | `connected / connecting / disconnected / failed` |
| `tunnelName` | 当前隧道名称 |
| `endpoint` | 当前 Endpoint |
| `lastHandshakeAt` | 最近握手时间 |
| `rxBytes` | 接收流量 |
| `txBytes` | 发送流量 |
| `primaryAction` | 连接 / 断开 / 重试 |
| `secondaryAction` | 查看详情 / 诊断 |

状态样式：

| 状态 | 背景 | 主按钮 |
|---|---|---|
| 已连接 | `success_bg` | 断开连接，Danger |
| 连接中 | `primary_bg` | 取消连接，中性 |
| 未连接 | `surface` | 连接，Primary |
| 失败 | `danger_bg` | 重试，Primary |

#### `DiagnosticSummaryCard`

展示最多 3-4 个摘要项：

```text
Endpoint 可达
DNS 正常
最近握手 15 秒前
MTU 1420
```

异常时优先展示异常：

```text
DNS 解析失败
最近握手超过 2 分钟
Endpoint 无响应
```

#### `TunnelListItem`

```text
[图标] 公司内网                    [已连接]
      vpn.example.com:51820
      全局代理 · DNS 1.1.1.1 · Keepalive 25s
```

交互：

| 操作 | 行为 |
|---|---|
| 点击 | 打开隧道详情 |
| 右侧按钮 | 连接 / 断开 |
| 长按 | 编辑、复制、导出、删除 |
| 左滑 | 删除或更多操作 |
| 下拉刷新 | 刷新运行状态 |

### 9.4 空状态

```text
暂无 VPN 配置

你可以通过二维码、配置文件或剪贴板导入 WireGuard 配置。

[扫描二维码]
[从文件导入]
[手动创建]
```

---

## 10. 添加配置页 `ImportConfigPage.ets`

### 10.1 页面目标

提供最短路径导入 WireGuard 配置。

### 10.2 布局

```text
┌─────────────────────────────┐
│ 添加配置                    │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 扫描二维码               │ │
│ │ 使用相机扫描 WireGuard   │ │
│ │ 配置二维码               │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 从文件导入               │ │
│ │ 选择 .conf 配置文件      │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 从剪贴板导入             │ │
│ │ 粘贴 WireGuard 配置文本  │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 手动创建                 │ │
│ │ 自行填写 Interface/Peer  │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### 10.3 交互

| 入口 | 行为 |
|---|---|
| 扫描二维码 | 请求相机权限，解析二维码文本 |
| 从文件导入 | 打开文件选择器，仅提示 `.conf` |
| 从剪贴板导入 | 读取剪贴板文本并解析 |
| 手动创建 | 进入配置编辑页，字段为空 |

### 10.4 错误处理

| 错误 | 提示 |
|---|---|
| 不是 WireGuard 配置 | “未识别到有效的 WireGuard 配置” |
| 缺少 PrivateKey | “配置缺少本机私钥” |
| 缺少 Peer PublicKey | “配置缺少服务器公钥” |
| Endpoint 格式错误 | “服务器地址或端口格式不正确” |
| AllowedIPs 为空 | “未配置路由范围，连接后可能无法访问目标网络” |

---

## 11. 导入预览页 `ConfigPreviewPage.ets`

### 11.1 页面目标

导入配置后，先让用户看懂配置含义，再保存。

### 11.2 布局

```text
┌─────────────────────────────┐
│ 导入预览                保存 │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 公司内网                 │ │
│ │ WireGuard 配置已解析     │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ Interface 本机接口       │ │
│ │ Address: 10.0.0.2/32    │ │
│ │ DNS: 1.1.1.1            │ │
│ │ MTU: 自动               │ │
│ │ PrivateKey: 已设置       │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ Peer 对端服务器          │ │
│ │ Endpoint: vpn.example... │ │
│ │ PublicKey: abcd...xyz   │ │
│ │ Keepalive: 25s          │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 路由模式                 │ │
│ │ 全局代理                 │ │
│ │ 0.0.0.0/0, ::/0          │ │
│ └─────────────────────────┘ │
│                             │
│ ⚠ 此配置会接管全部网络流量   │
│                             │
│ [编辑配置]          [保存]   │
└─────────────────────────────┘
```

### 11.3 风险提示规则

| 条件 | 提示 |
|---|---|
| `AllowedIPs` 包含 `0.0.0.0/0` | “此配置会转发全部 IPv4 流量” |
| `AllowedIPs` 包含 `::/0` | “此配置会转发全部 IPv6 流量” |
| 未配置 DNS | “未配置 DNS，连接后可能仍使用本地 DNS” |
| 未配置 Keepalive | “移动网络/NAT 环境下可能需要 Keepalive” |
| Endpoint 是域名 | “连接时会先解析域名” |
| MTU 未设置 | “将使用自动 MTU 或默认值” |

---

## 12. 配置编辑页 `ConfigEditPage.ets`

### 12.1 页面目标

让用户安全、清晰地编辑 WireGuard 配置。技术字段保留，但通过分组和说明降低误用概率。

### 12.2 页面结构

```text
配置编辑
├── 显示信息
│   ├── 配置名称
│   └── 图标/颜色
├── Interface 本机接口
│   ├── Address
│   ├── PrivateKey
│   ├── DNS
│   └── MTU
├── Peer 对端服务器
│   ├── PublicKey
│   ├── Endpoint Host
│   ├── Endpoint Port
│   ├── AllowedIPs
│   ├── PersistentKeepalive
│   └── PresharedKey
└── 高级设置
    ├── 自动连接
    ├── 网络变化后重连
    ├── 允许访问本地网络
    ├── IPv6 防泄漏
    └── 日志级别
```

### 12.3 布局

```text
┌─────────────────────────────┐
│ ← 编辑配置              保存 │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 显示信息                 │ │
│ │ 配置名称 *               │ │
│ │ [公司内网              ] │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ Interface 本机接口       │ │
│ │ Address *                │ │
│ │ [10.0.0.2/32           ] │ │
│ │ PrivateKey *             │ │
│ │ [已设置] [查看] [替换]   │ │
│ │ DNS                      │ │
│ │ [1.1.1.1] [8.8.8.8] [+]  │ │
│ │ MTU                      │ │
│ │ [自动]                  │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ Peer 对端服务器          │ │
│ │ PublicKey *              │ │
│ │ [abcd...xyz] [复制]      │ │
│ │ Endpoint *               │ │
│ │ [vpn.example.com] [51820]│ │
│ │ 路由模式                 │ │
│ │ (●) 全局代理             │ │
│ │ ( ) 仅访问内网           │ │
│ │ ( ) 自定义               │ │
│ │ Keepalive                │ │
│ │ [25 秒]                  │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 高级设置                 │ │
│ │ 自动连接        [开关]   │ │
│ │ 网络变化重连    [开关]   │ │
│ │ IPv6 防泄漏     [开关]   │ │
│ └─────────────────────────┘ │
│                             │
│ [删除此配置]                 │
└─────────────────────────────┘
```

### 12.4 路由模式选择器

```text
路由模式

(●) 全局代理
    所有 IPv4/IPv6 流量通过 VPN
    0.0.0.0/0, ::/0

( ) 仅访问内网
    只将指定网段发送到 VPN
    [192.168.3.0/24] [10.0.0.0/8] [+]

( ) 自定义
    手动配置 AllowedIPs
    [添加 CIDR]
```

### 12.5 字段规范

| 字段 | 类型 | 必填 | 验证 |
|---|---|---:|---|
| 配置名称 | TextInput | 是 | 非空，长度 1-64 |
| Address | TokenInput | 是 | IPv4/IPv6 CIDR |
| PrivateKey | SecureKeyField | 是 | Base64 32 字节密钥 |
| DNS | TokenInput | 否 | IPv4/IPv6 地址 |
| MTU | NumberInput | 否 | 576-1500，默认自动 |
| PublicKey | KeyField | 是 | Base64 32 字节密钥 |
| Endpoint Host | TextInput | 是 | IP 或域名 |
| Endpoint Port | NumberInput | 是 | 1-65535 |
| AllowedIPs | CidrTokenInput | 是 | IPv4/IPv6 CIDR |
| Keepalive | NumberInput | 否 | 0-65535，0 表示关闭 |
| PresharedKey | SecureKeyField | 否 | Base64 32 字节密钥 |

### 12.6 安全交互

#### 查看私钥确认

```text
显示私钥？

私钥可用于控制此 VPN 身份。请勿截图、转发或粘贴到不可信应用。

[取消] [显示 30 秒]
```

规则：

- 私钥显示 30 秒后自动隐藏。
- App 进入后台时立即隐藏。
- 截屏检测如平台支持，可显示风险提示。
- 私钥不进入普通日志。
- 复制私钥后提示“请及时清空剪贴板”。

#### 删除配置确认

```text
删除配置？

此操作将删除本地保存的 WireGuard 配置和相关密钥引用，无法撤销。

[取消] [删除]
```

---

## 13. 隧道详情页 `TunnelDetailPage.ets`

### 13.1 页面目标

状态页不只展示“已连接”，还要承担故障排查功能。

### 13.2 页面结构

```text
隧道详情
├── 状态摘要
├── 实时流量
├── 路由信息
├── 诊断检查
└── 运行日志
```

### 13.3 手机端布局

```text
┌─────────────────────────────┐
│ ← 公司内网                  │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ ● 已连接                 │ │
│ │ 最近握手：15 秒前        │ │
│ │ Endpoint: vpn.example... │ │
│ │ 本机地址：10.0.0.2/32    │ │
│ │ [断开连接]               │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 实时流量                 │ │
│ │ ↓ 128 KB/s    ↑ 32 KB/s  │ │
│ │ [流量图表]               │ │
│ │ 总接收 1.2GB 总发送856MB │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 路由信息                 │ │
│ │ 模式：全局代理           │ │
│ │ AllowedIPs: 0.0.0.0/0... │ │
│ │ DNS: 1.1.1.1             │ │
│ │ MTU: 1420                │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 诊断                     │ │
│ │ ✓ Endpoint 可达          │ │
│ │ ✓ DNS 正常               │ │
│ │ ✓ 最近握手正常           │ │
│ │ ! IPv6 可能未接管        │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 最近日志                 │ │
│ │ 12:01 握手成功           │ │
│ │ 12:00 Endpoint 已解析    │ │
│ │ [导出诊断报告]           │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### 13.4 指标说明

| 指标 | 展示 | 来源 |
|---|---|---|
| 连接状态 | 已连接/连接中/失败/未连接 | VPN 服务运行态 |
| 最近握手 | x 秒前 / 从未握手 | WireGuard 运行态 |
| 接收流量 | 总接收、实时速率 | WireGuard 运行态 |
| 发送流量 | 总发送、实时速率 | WireGuard 运行态 |
| Endpoint | host:port | 配置 + 解析结果 |
| DNS | DNS 列表 | 配置 |
| MTU | 当前 MTU | 配置或运行态 |
| 路由模式 | 全局代理/仅内网/自定义 | AllowedIPs 推导 |
| 延迟 | x ms | App 主动探测 |
| 丢包率 | 不默认展示 | 需主动探测，不直接来自 WireGuard |

### 13.5 诊断检查项

| 检查项 | 正常状态 | 异常提示 |
|---|---|---|
| VPN 权限 | 已授权 | “需要系统 VPN 权限” |
| Endpoint 解析 | 已解析 IP | “域名解析失败” |
| Endpoint 连通性 | 可达 | “服务器无响应或端口不可达” |
| 握手状态 | 最近 2 分钟内握手 | “长时间未握手，可能密钥或网络错误” |
| DNS | 可解析测试域名 | “DNS 不可用” |
| 路由 | AllowedIPs 非空 | “未配置路由范围” |
| IPv6 | 已接管或明确关闭 | “IPv6 可能绕过 VPN” |
| 本地网络 | 可访问或按配置阻断 | “本地网络访问被 VPN 路由覆盖” |

---

## 14. 设置页 `SettingsPage.ets`

### 14.1 页面结构

```text
设置
├── 连接行为
│   ├── 启动时自动连接
│   ├── 网络变化后自动重连
│   ├── 连接失败自动重试
│   └── 默认连接配置
├── 路由与网络
│   ├── 允许访问本地网络
│   ├── IPv6 防泄漏
│   ├── 默认 MTU 策略
│   └── DNS 泄漏检测
├── 隐私与安全
│   ├── 私钥显示二次确认
│   ├── 导出配置二次确认
│   ├── 自动清除剪贴板
│   └── 日志脱敏
├── 外观
│   ├── 跟随系统深色模式
│   ├── 紧凑模式
│   └── 状态栏显示流量
└── 关于
    ├── 版本
    ├── 开源协议
    └── 隐私说明
```

### 14.2 设置项建议

| 设置 | 默认值 | 说明 |
|---|---|---|
| 网络变化后重连 | 开 | 移动网络/Wi-Fi 切换后重连 |
| 连接失败自动重试 | 开 | 使用指数退避 |
| 允许访问本地网络 | 开 | 避免全局代理影响局域网设备访问 |
| IPv6 防泄漏 | 开 | 全局代理时尤其重要 |
| 日志脱敏 | 开 | 隐藏密钥、完整 Endpoint、IP 尾段 |
| 自动清除剪贴板 | 开 | 复制敏感字段后延迟清除 |
| 紧凑模式 | 关 | PC/大屏可开启 |

---

## 15. 公共组件规范

### 15.1 组件清单

```text
components/
├── app/
│   ├── AppNavigation.ets
│   ├── AdaptiveScaffold.ets
│   └── PageHeader.ets
├── tunnel/
│   ├── ConnectionHeroCard.ets
│   ├── TunnelListItem.ets
│   ├── TunnelStatusBadge.ets
│   ├── TunnelActionButton.ets
│   └── RouteModeSelector.ets
├── config/
│   ├── ConfigImportPanel.ets
│   ├── ConfigPreviewCard.ets
│   ├── KeyField.ets
│   ├── SecureKeyField.ets
│   ├── CidrTokenInput.ets
│   ├── EndpointInput.ets
│   └── AdvancedSection.ets
├── diagnostics/
│   ├── TrafficChart.ets
│   ├── HandshakeCard.ets
│   ├── DiagnosticChecklist.ets
│   ├── RuntimeLogList.ets
│   └── ExportReportButton.ets
└── common/
    ├── EmptyState.ets
    ├── ConfirmDialog.ets
    ├── SecureConfirmDialog.ets
    ├── InfoBanner.ets
    ├── StatusBadge.ets
    └── SectionCard.ets
```

### 15.2 `ConnectionHeroCard`

```typescript
@Component
struct ConnectionHeroCard {
  @Prop status: TunnelStatus
  @Prop tunnelName?: string
  @Prop endpoint?: string
  @Prop lastHandshakeAt?: number
  @Prop rxBytes: number
  @Prop txBytes: number
  @Prop latestError?: string

  onPrimaryAction: () => void
  onDetail: () => void
}
```

视觉规则：

| 状态 | 视觉 |
|---|---|
| 已连接 | 绿色状态点，弱绿色背景 |
| 连接中 | 蓝色状态点，LoadingProgress |
| 未连接 | 灰色状态点，白色背景 |
| 失败 | 红色状态点，弱红背景，显示错误摘要 |

### 15.3 `TunnelListItem`

```typescript
@Component
struct TunnelListItem {
  @Prop profile: TunnelProfile
  @Prop runtime?: TunnelRuntimeState
  @Prop selected: boolean

  onSelect: () => void
  onConnect: () => void
  onDisconnect: () => void
  onMore: () => void
}
```

### 15.4 `RouteModeSelector`

```typescript
@Component
struct RouteModeSelector {
  @Prop routeMode: RouteMode
  @Prop allowedIPs: string[]

  onRouteModeChange: (mode: RouteMode) => void
  onAllowedIPsChange: (cidrs: string[]) => void
}
```

### 15.5 `SecureKeyField`

```typescript
@Component
struct SecureKeyField {
  @Prop label: string
  @Prop hasValue: boolean
  @Prop maskedPreview?: string

  onReplace: () => void
  onReveal: () => void
  onCopy?: () => void
}
```

交互规则：

- 默认显示“已设置”。
- 点击查看时弹出 `SecureConfirmDialog`。
- 查看 30 秒后自动隐藏。
- App 后台化时自动隐藏。
- 复制时显示风险提示。

### 15.6 `DiagnosticChecklist`

```typescript
@Component
struct DiagnosticChecklist {
  @Prop items: DiagnosticItem[]

  onRunAgain: () => void
  onOpenLog: () => void
}
```

```typescript
export interface DiagnosticItem {
  id: string
  title: string
  status: 'pass' | 'warning' | 'fail' | 'checking'
  description?: string
  suggestion?: string
}
```

---

## 16. 动效规范

### 16.1 页面转场

| 场景 | 动效 |
|---|---|
| 首页 → 详情 | 右滑进入 |
| 首页 → 添加配置 | 底部上滑或右滑进入 |
| 编辑保存返回 | 淡出 + 返回 |
| 平板右侧详情切换 | 轻量淡入，不整页跳转 |

建议参数：

```typescript
PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
  .slide(SlideEffect.Right)
  .opacity(0)

PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
  .opacity(1)
```

### 16.2 连接状态动效

| 状态变化 | 动效 |
|---|---|
| 未连接 → 连接中 | 主按钮变 Loading |
| 连接中 → 已连接 | 状态点由蓝变绿，卡片轻微高亮 |
| 已连接 → 断开 | 卡片背景回到默认 |
| 失败 | 红色提示条滑入 |

### 16.3 列表交互

| 操作 | 动效 |
|---|---|
| 按下卡片 | scale 0.98 |
| 长按 | 弹出菜单 |
| 左滑 | 露出操作按钮 |
| 下拉刷新 | 系统刷新动效 |

---

## 17. 数据模型

### 17.1 配置模型

```typescript
export interface TunnelProfile {
  id: string
  name: string
  icon?: string
  color?: string
  interface: WgInterfaceConfig
  peers: WgPeerConfig[]
  routeMode: RouteMode
  behavior: TunnelBehavior
  createdAt: number
  updatedAt: number
}

export interface WgInterfaceConfig {
  privateKeyRef: string
  publicKey?: string
  addresses: string[]
  dns: string[]
  mtu?: number
  listenPort?: number
}

export interface WgPeerConfig {
  publicKey: string
  presharedKeyRef?: string
  endpointHost: string
  endpointPort: number
  allowedIPs: string[]
  persistentKeepalive?: number
}

export type RouteMode =
  | 'global'
  | 'lanOnly'
  | 'custom'

export interface TunnelBehavior {
  autoConnect: boolean
  reconnectOnNetworkChange: boolean
  allowLanAccess: boolean
  blockIpv6Leak: boolean
}
```

### 17.2 运行态模型

```typescript
export interface TunnelRuntimeState {
  tunnelId: string
  status: 'disconnected' | 'connecting' | 'connected' | 'failed'
  lastHandshakeAt?: number
  rxBytes: number
  txBytes: number
  rxSpeed?: number
  txSpeed?: number
  endpointResolvedIp?: string
  latestError?: string
  updatedAt: number
}
```

### 17.3 诊断模型

```typescript
export interface TunnelDiagnosticState {
  tunnelId: string
  permission: DiagnosticItem
  endpointResolve: DiagnosticItem
  endpointReachability: DiagnosticItem
  handshake: DiagnosticItem
  dns: DiagnosticItem
  route: DiagnosticItem
  ipv6: DiagnosticItem
  localNetwork: DiagnosticItem
  updatedAt: number
}
```

### 17.4 日志模型

```typescript
export interface RuntimeLogEntry {
  id: string
  tunnelId: string
  level: 'debug' | 'info' | 'warning' | 'error'
  message: string
  detail?: string
  timestamp: number
}
```

日志规则：

- 禁止写入 `PrivateKey`。
- 禁止写入完整 `PresharedKey`。
- Endpoint、IP 可根据日志级别脱敏。
- 导出诊断报告时默认脱敏。

---

## 18. 配置解析规则

### 18.1 WireGuard 配置结构

支持解析：

```ini
[Interface]
PrivateKey = ...
Address = 10.0.0.2/32
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = ...
PresharedKey = ...
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

### 18.2 路由模式推导

| AllowedIPs | 推导 |
|---|---|
| `0.0.0.0/0` | IPv4 全局代理 |
| `::/0` | IPv6 全局代理 |
| `0.0.0.0/0, ::/0` | IPv4/IPv6 全局代理 |
| 私有网段，如 `192.168.0.0/16` | 仅访问内网 |
| 多个非默认路由 | 自定义 |
| 空 | 异常，提示未配置路由 |

### 18.3 Endpoint 解析

| 输入 | 解析 |
|---|---|
| `vpn.example.com:51820` | host = `vpn.example.com`, port = `51820` |
| `1.2.3.4:51820` | host = `1.2.3.4`, port = `51820` |
| `[2001:db8::1]:51820` | host = `2001:db8::1`, port = `51820` |

---

## 19. 资源文件规划

### 19.1 目录结构

```text
entry/src/main/resources/
├── base/
│   └── element/
│       ├── color.json
│       ├── float.json
│       ├── string.json
│       └── plural.json
├── dark/
│   └── element/
│       └── color.json
└── media/
    ├── ic_tunnel.svg
    ├── ic_key.svg
    ├── ic_globe.svg
    ├── ic_home.svg
    ├── ic_server.svg
    └── ic_diagnostics.svg
```

### 19.2 `color.json`

```json
{
  "color": [
    { "name": "primary", "value": "#007DFF" },
    { "name": "primary_dark", "value": "#0056CC" },
    { "name": "success", "value": "#00B386" },
    { "name": "warning", "value": "#FF8800" },
    { "name": "danger", "value": "#FA2C2C" },
    { "name": "info", "value": "#007DFF" },
    { "name": "background", "value": "#F1F3F5" },
    { "name": "surface", "value": "#FFFFFF" },
    { "name": "surface_subtle", "value": "#F7F9FA" },
    { "name": "text_primary", "value": "#E6000000" },
    { "name": "text_secondary", "value": "#99000000" },
    { "name": "text_tertiary", "value": "#66000000" },
    { "name": "divider", "value": "#1F000000" },
    { "name": "success_bg", "value": "#E8F8F3" },
    { "name": "warning_bg", "value": "#FFF3E0" },
    { "name": "danger_bg", "value": "#FFEBEE" },
    { "name": "primary_bg", "value": "#EAF4FF" }
  ]
}
```

### 19.3 `dark/element/color.json`

```json
{
  "color": [
    { "name": "background", "value": "#121212" },
    { "name": "surface", "value": "#1E1E1E" },
    { "name": "surface_subtle", "value": "#252525" },
    { "name": "text_primary", "value": "#E6FFFFFF" },
    { "name": "text_secondary", "value": "#99FFFFFF" },
    { "name": "text_tertiary", "value": "#66FFFFFF" },
    { "name": "divider", "value": "#1FFFFFFF" },
    { "name": "success_bg", "value": "#123D32" },
    { "name": "warning_bg", "value": "#3A2A10" },
    { "name": "danger_bg", "value": "#3A1616" },
    { "name": "primary_bg", "value": "#102A44" }
  ]
}
```

### 19.4 `float.json`

```json
{
  "float": [
    { "name": "spacing_xs", "value": "4vp" },
    { "name": "spacing_sm", "value": "8vp" },
    { "name": "spacing_md", "value": "16vp" },
    { "name": "spacing_lg", "value": "24vp" },
    { "name": "spacing_xl", "value": "32vp" },

    { "name": "radius_sm", "value": "8vp" },
    { "name": "radius_md", "value": "12vp" },
    { "name": "radius_lg", "value": "16vp" },
    { "name": "radius_xl", "value": "24vp" },

    { "name": "page_padding", "value": "16vp" },
    { "name": "header_height", "value": "56vp" },
    { "name": "button_height", "value": "48vp" },
    { "name": "card_min_height", "value": "72vp" },
    { "name": "fab_size", "value": "56vp" },

    { "name": "compact_breakpoint", "value": "600vp" },
    { "name": "expanded_breakpoint", "value": "840vp" }
  ]
}
```

### 19.5 `string.json`

```json
{
  "string": [
    { "name": "app_name", "value": "WireGuard" },

    { "name": "page_home", "value": "WireGuard" },
    { "name": "page_import_config", "value": "添加配置" },
    { "name": "page_config_preview", "value": "导入预览" },
    { "name": "page_config_edit", "value": "编辑配置" },
    { "name": "page_tunnel_detail", "value": "连接详情" },
    { "name": "page_settings", "value": "设置" },

    { "name": "status_connected", "value": "已连接" },
    { "name": "status_connecting", "value": "连接中" },
    { "name": "status_disconnected", "value": "未连接" },
    { "name": "status_failed", "value": "连接失败" },

    { "name": "button_connect", "value": "连接" },
    { "name": "button_disconnect", "value": "断开连接" },
    { "name": "button_retry", "value": "重试" },
    { "name": "button_detail", "value": "查看详情" },
    { "name": "button_add_config", "value": "添加配置" },
    { "name": "button_scan_qr", "value": "扫描二维码" },
    { "name": "button_import_file", "value": "从文件导入" },
    { "name": "button_import_clipboard", "value": "从剪贴板导入" },
    { "name": "button_create_manual", "value": "手动创建" },
    { "name": "button_save", "value": "保存" },
    { "name": "button_edit", "value": "编辑" },
    { "name": "button_delete", "value": "删除" },
    { "name": "button_cancel", "value": "取消" },
    { "name": "button_export_report", "value": "导出诊断报告" },

    { "name": "section_current_connection", "value": "当前连接" },
    { "name": "section_diagnostics", "value": "诊断" },
    { "name": "section_configs", "value": "配置" },
    { "name": "section_display", "value": "显示信息" },
    { "name": "section_interface", "value": "Interface 本机接口" },
    { "name": "section_peer", "value": "Peer 对端服务器" },
    { "name": "section_route_dns", "value": "路由与 DNS" },
    { "name": "section_advanced", "value": "高级设置" },

    { "name": "field_name", "value": "配置名称" },
    { "name": "field_private_key", "value": "PrivateKey" },
    { "name": "field_public_key", "value": "PublicKey" },
    { "name": "field_address", "value": "Address" },
    { "name": "field_dns", "value": "DNS" },
    { "name": "field_mtu", "value": "MTU" },
    { "name": "field_endpoint_host", "value": "服务器地址" },
    { "name": "field_endpoint_port", "value": "端口" },
    { "name": "field_allowed_ips", "value": "AllowedIPs" },
    { "name": "field_keepalive", "value": "PersistentKeepalive" },
    { "name": "field_preshared_key", "value": "PresharedKey" },

    { "name": "route_global", "value": "全局代理" },
    { "name": "route_lan_only", "value": "仅访问内网" },
    { "name": "route_custom", "value": "自定义路由" },

    { "name": "empty_config_title", "value": "暂无 VPN 配置" },
    { "name": "empty_config_desc", "value": "你可以通过二维码、配置文件或剪贴板导入 WireGuard 配置。" },

    { "name": "dialog_reveal_key_title", "value": "显示私钥？" },
    { "name": "dialog_reveal_key_message", "value": "私钥可用于控制此 VPN 身份。请勿截图、转发或粘贴到不可信应用。" },
    { "name": "dialog_export_config_title", "value": "导出配置？" },
    { "name": "dialog_export_config_message", "value": "导出的配置包含私钥，任何获得该文件的人都可以使用此隧道。" },
    { "name": "dialog_delete_config_title", "value": "删除配置？" },
    { "name": "dialog_delete_config_message", "value": "此操作将删除本地保存的 WireGuard 配置和相关密钥引用，无法撤销。" },

    { "name": "error_required", "value": "此项为必填项" },
    { "name": "error_invalid_key", "value": "密钥格式不正确" },
    { "name": "error_invalid_endpoint", "value": "服务器地址或端口格式不正确" },
    { "name": "error_invalid_cidr", "value": "CIDR 格式不正确" },
    { "name": "error_invalid_dns", "value": "DNS 地址格式不正确" },
    { "name": "error_invalid_mtu", "value": "MTU 范围不正确" }
  ]
}
```

---

## 20. 文件结构规划

```text
entry/src/main/ets/
├── app/
│   ├── App.ets
│   ├── AppRouter.ets
│   └── AdaptiveScaffold.ets
├── common/
│   ├── Constants.ets
│   ├── DesignSystem.ets
│   ├── Formatters.ets
│   ├── Validators.ets
│   └── Utils.ets
├── components/
│   ├── app/
│   ├── tunnel/
│   ├── config/
│   ├── diagnostics/
│   └── common/
├── pages/
│   ├── Index.ets
│   ├── ImportConfigPage.ets
│   ├── ConfigPreviewPage.ets
│   ├── ConfigEditPage.ets
│   ├── TunnelDetailPage.ets
│   ├── SettingsPage.ets
│   └── AboutPage.ets
├── model/
│   ├── TunnelProfile.ts
│   ├── WgConfig.ts
│   ├── TunnelRuntimeState.ts
│   ├── Diagnostics.ts
│   └── RuntimeLog.ts
├── service/
│   ├── ConfigParser.ts
│   ├── ConfigManager.ts
│   ├── SecureKeyStore.ts
│   ├── TunnelRuntimeService.ts
│   ├── DiagnosticService.ts
│   └── LogService.ts
└── vpn/
    ├── WireGuardEngineAdapter.ts
    └── VpnAbilityOrExtension.ets
```

说明：

- `vpn/` 目录只作为 UI 与底层 VPN 能力之间的适配层命名建议。
- 具体 Ability、Extension、权限和系统 API 需要结合实际 SDK 能力确认。
- UI 层不应直接依赖系统 VPN 实现细节，应通过 `TunnelRuntimeService` 获取状态。

---

## 21. 校验规则

### 21.1 Key 校验

| 字段 | 规则 |
|---|---|
| PrivateKey | Base64 编码，解码后应为 32 字节 |
| PublicKey | Base64 编码，解码后应为 32 字节 |
| PresharedKey | 可选；Base64 编码，解码后应为 32 字节 |

### 21.2 Endpoint 校验

| 项 | 规则 |
|---|---|
| Host | 域名、IPv4 或 IPv6 |
| Port | 1-65535 |
| IPv6 Endpoint | 需要支持 `[IPv6]:port` 格式 |

### 21.3 CIDR 校验

| 项 | 规则 |
|---|---|
| IPv4 CIDR | `x.x.x.x/0-32` |
| IPv6 CIDR | `xxxx::/0-128` |
| 多个 CIDR | 逗号分隔或 Token 输入 |

### 21.4 MTU 校验

| 项 | 规则 |
|---|---|
| 默认 | 自动 |
| 手动 | 576-1500 |
| 推荐值 | 1420 |

---

## 22. 无障碍与国际化

### 22.1 无障碍

每个交互元素需要提供：

| 元素 | 无障碍文本 |
|---|---|
| 连接按钮 | “连接 公司内网” |
| 断开按钮 | “断开 公司内网” |
| 配置项 | “公司内网，已连接，全局代理” |
| 私钥查看 | “显示私钥，敏感操作” |
| 路由模式 | “全局代理，所有流量通过 VPN” |
| 诊断项 | “DNS 正常”或“DNS 异常” |

要求：

- 所有按钮最小可点击区域不小于 `48vp`。
- 状态不能只靠颜色表达，需要文字。
- 错误输入框必须有错误文本。
- 支持系统字体缩放。
- 支持深色模式。

### 22.2 国际化

所有可见文本进入 `string.json`。建议初期至少支持：

| 语言 | 文件 |
|---|---|
| 简体中文 | `resources/zh_CN/element/string.json` |
| 英文 | `resources/en_US/element/string.json` |

---

## 23. 性能设计

### 23.1 列表性能

- 配置列表使用 `LazyForEach`。
- 运行态刷新只更新变化项，不重建整个列表。
- 大屏日志使用虚拟列表或分页。

### 23.2 图表性能

- 实时流量图使用 Canvas 或轻量自绘。
- 刷新频率建议 1s。
- 页面不可见时暂停刷新。
- 保留最近 60-120 个采样点即可。

### 23.3 状态刷新

| 数据 | 刷新频率 |
|---|---:|
| 连接状态 | 事件驱动 + 1s 兜底 |
| 流量速率 | 1s |
| 最近握手 | 1s |
| 诊断检查 | 手动触发 + 连接失败时触发 |
| 日志 | 事件驱动 |

---

## 24. 安全与隐私

### 24.1 敏感数据

| 数据 | 存储策略 |
|---|---|
| PrivateKey | 安全存储，只保存引用 |
| PresharedKey | 安全存储，只保存引用 |
| PublicKey | 可明文保存 |
| Endpoint | 可保存，但日志可脱敏 |
| 配置文件导出 | 二次确认 |
| 诊断日志 | 默认脱敏 |

### 24.2 敏感操作确认

需要二次确认的操作：

- 查看私钥
- 复制私钥
- 导出包含私钥的配置
- 删除配置
- 清空日志
- 重置所有配置

### 24.3 日志脱敏

示例：

```text
原始：
Endpoint: vpn.example.com:51820
PrivateKey: abcdefg...

脱敏：
Endpoint: vpn.example.com:51820
PrivateKey: [REDACTED]
```

IP 脱敏可选：

```text
192.168.3.210 → 192.168.3.xxx
```

---

## 25. 错误状态与提示

### 25.1 连接失败错误

| 错误 | 用户提示 | 操作 |
|---|---|---|
| 未授权 VPN 权限 | “需要授予 VPN 权限才能连接” | 打开授权 |
| Endpoint 解析失败 | “服务器域名解析失败” | 检查 DNS / Endpoint |
| Endpoint 不可达 | “服务器无响应” | 运行诊断 |
| 握手超时 | “长时间未完成握手” | 检查密钥、时间、网络 |
| AllowedIPs 为空 | “未配置路由范围” | 编辑配置 |
| DNS 不可用 | “连接后 DNS 解析失败” | 修改 DNS |
| IPv6 泄漏风险 | “IPv6 未被 VPN 接管” | 开启 IPv6 防泄漏 |

### 25.2 表单错误

错误展示规则：

- 输入框边框变红。
- 下方展示错误文本。
- 保存时滚动到第一个错误字段。
- 错误文本要明确，不只写“格式错误”。

---

## 26. 开发优先级

### Phase 1：MVP

目标：完成可用的 WireGuard 客户端 UI 主流程。

1. 首页连接控制台
2. 配置导入页
3. 配置解析预览页
4. 配置保存
5. 配置列表
6. 连接 / 断开状态展示
7. 基础错误提示

### Phase 2：编辑和安全

1. 配置编辑页
2. 私钥安全字段
3. 删除确认
4. 导出确认
5. 字段验证
6. 路由模式选择器
7. 深色模式

### Phase 3：诊断能力

1. 隧道详情页
2. 流量统计
3. 最近握手
4. Endpoint 解析检查
5. DNS 检查
6. IPv6 风险提示
7. 日志页和诊断报告导出

### Phase 4：多端适配

1. 手机单栏
2. 平板双栏
3. PC/大屏三栏
4. 折叠屏横竖屏适配
5. 键盘快捷操作
6. 紧凑模式

---

## 27. 验收清单

### 27.1 UI 验收

- [ ] 首页打开后能立即看到当前连接状态。
- [ ] 未配置时有清晰导入入口。
- [ ] 已连接、连接中、失败、未连接四种状态视觉明确。
- [ ] 配置列表能区分全局代理和仅访问内网。
- [ ] 配置编辑页字段分组清晰。
- [ ] `AllowedIPs` 不只暴露原始输入，有路由模式解释。
- [ ] 私钥默认隐藏。
- [ ] 查看私钥有二次确认。
- [ ] 导出配置有风险提示。
- [ ] 深色模式可读。
- [ ] 字体放大后布局不崩。
- [ ] 手机、平板、PC 布局均可用。

### 27.2 WireGuard 功能验收

- [ ] 支持解析 `[Interface]`。
- [ ] 支持解析 `[Peer]`。
- [ ] 支持多个 Address。
- [ ] 支持多个 DNS。
- [ ] 支持多个 AllowedIPs。
- [ ] 支持 Endpoint 域名、IPv4、IPv6。
- [ ] 支持 PersistentKeepalive。
- [ ] 支持 PresharedKey。
- [ ] 能展示接收/发送流量。
- [ ] 能展示最近握手。
- [ ] 连接失败时能展示原因。

### 27.3 多端验收

- [ ] 手机单栏可用。
- [ ] 平板双栏可用。
- [ ] 大屏三栏可用。
- [ ] 横屏时不浪费空间。
- [ ] 配置列表和详情可以同时展示。
- [ ] 诊断日志在大屏上可常驻。

---

## 28. 与初版方案的主要变化

| 初版 | 优化后 |
|---|---|
| 首页以配置卡片为核心 | 首页以当前连接控制台为核心 |
| 添加配置依赖 FAB | 添加配置成为独立入口，支持多种导入 |
| 状态页只展示流量和统计 | 隧道详情页展示状态、路由、诊断、日志 |
| 手动表单优先 | 导入优先，手动编辑作为高级能力 |
| `AllowedIPs` 直接输入 | 路由模式选择 + CIDR 高级编辑 |
| Emoji 图标 | 统一线性图标 / Symbol 图标 |
| 手机布局为主 | 单栏、双栏、三栏完整适配 |
| 丢包率默认展示 | 不默认展示，除非 App 主动探测 |
| 私钥只隐藏显示 | 私钥查看、复制、导出全链路安全确认 |

---

## 29. 参考资料

- HarmonyOS 设计理念：`https://developer.huawei.com/consumer/cn/design/concept/`
- HarmonyOS 应用开发知识地图：`https://developer.huawei.com/consumer/cn/app/knowledge-map/`
- HUAWEI Developers HarmonyOS 概览：`https://developer.huawei.com/consumer/en/`
- HarmonyOS Stage 模型开发概述：`https://developer.huawei.com/consumer/cn/arkui/arkui-stage/`
- WireGuard Cross-platform Interface：`https://www.wireguard.com/xplatform/`
- WireGuard `wg` 工具手册：`https://www.mankier.com/8/wg`

---

## 30. 最终结论

本设计方案将应用定位为 **HarmonyOS 多端 WireGuard 连接控制台**，而不是简单的 WireGuard 配置管理器。

核心设计方向：

1. 首页优先展示当前连接，而不是只展示配置列表。
2. 配置导入优先，降低手动填写错误率。
3. 将 `AllowedIPs` 转换成用户可理解的路由模式。
4. 状态页升级为隧道详情页，包含状态、流量、握手、路由、诊断、日志。
5. 私钥和配置导出按敏感操作处理。
6. 手机、平板、PC 使用同一业务模型，但采用不同布局密度。
