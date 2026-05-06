# HarmonyOS WireGuard VPN 界面设计方案

## 1. 设计系统规范

### 1.1 色彩体系

#### 主色调
- **Primary**: `#007DFF` (鸿蒙蓝) - 主按钮、开关、强调色
- **Primary Dark**: `#0056CC` - 按下状态
- **Success**: `#00B386` - 已连接状态
- **Warning**: `#FF8800` - 警告提示
- **Danger**: `#FA2C2C` - 断开连接、删除操作
- **Info**: `#007DFF` - 信息提示

#### 中性色
- **Text Primary**: `#E6000000` (90% 黑) - 主文本
- **Text Secondary**: `#99000000` (60% 黑) - 次要文本
- **Text Tertiary**: `#66000000` (40% 黑) - 辅助文本
- **Text Inverse**: `#FFFFFF` - 深色背景上的文本
- **Divider**: `#1F000000` (12% 黑) - 分割线
- **Background**: `#F1F3F5` - 页面背景
- **Surface**: `#FFFFFF` - 卡片、面板背景

#### 深色模式 (Dark Mode)
- **Background Dark**: `#121212`
- **Surface Dark**: `#1E1E1E`
- **Text Primary Dark**: `#E6FFFFFF`
- **Text Secondary Dark**: `#99FFFFFF`
- **Text Tertiary Dark**: `#66FFFFFF`

### 1.2 间距系统 (8px 基准网格)

```typescript
export const SPACING = {
  xs: 4,    // 极小间距
  sm: 8,    // 小间距
  md: 16,   // 中间距 (默认)
  lg: 24,   // 大间距
  xl: 32,   // 极大间距
  xxl: 48,  // 超大间距
} as const;
```

### 1.3 圆角系统

```typescript
export const RADIUS = {
  sm: 4,    // 小标签、输入框
  md: 8,    // 按钮
  lg: 12,   // 卡片
  xl: 16,   // 大卡片、对话框
  full: 999, // 胶囊按钮、头像
} as const;
```

### 1.4 字体层级

```typescript
export const TYPOGRAPHY = {
  h1: { size: 24, weight: FontWeight.Bold },      // 页面标题
  h2: { size: 20, weight: FontWeight.Bold },      // 卡片标题
  h3: { size: 18, weight: FontWeight.Medium },    // 列表项标题
  body: { size: 16, weight: FontWeight.Regular },  // 正文
  body2: { size: 14, weight: FontWeight.Regular }, // 次要文本
  caption: { size: 12, weight: FontWeight.Regular }, // 辅助说明
  overline: { size: 10, weight: FontWeight.Medium }, // 标签
} as const;
```

### 1.5 阴影系统

```typescript
export const SHADOW = {
  sm: { radius: 4, color: 'rgba(0,0,0,0.08)', offsetY: 2 },
  md: { radius: 8, color: 'rgba(0,0,0,0.12)', offsetY: 4 },
  lg: { radius: 16, color: 'rgba(0,0,0,0.16)', offsetY: 8 },
} as const;
```

---

## 2. 页面设计

### 2.1 首页 (Index.ets)

#### 布局结构
```
┌─────────────────────────────┐
│ [状态栏]                     │
│ ┌─────────────────────────┐ │
│ │ WireGuard      [● 已连接]│ │  ← Header
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🏢 公司内网              │ │  ← Config Card 1
│ │ vpn.example.com:51820   │ │
│ │ [延迟: 45ms]      [⚫──]│ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🏠 家庭网络              │ │  ← Config Card 2
│ │ home.example.com:51820  │ │
│ │ [延迟: 120ms]     [⚪──]│ │
│ └─────────────────────────┘ │
│                             │
│         [空状态插图]         │  ← Empty State (无配置时)
│      "点击右下角添加配置"      │
│                             │
│              ┌───┐          │
│              │ + │          │  ← FAB (悬浮按钮)
│              └───┘          │
└─────────────────────────────┘
```

#### 组件规范

**Header**
- 高度: 56vp
- 背景: Surface
- 标题: "WireGuard", h1 样式
- 右侧: 全局连接状态指示器 (圆形 + 文字)

**Config Card**
- 背景: Surface
- 圆角: RADIUS.lg (12)
- 阴影: SHADOW.sm
- 内边距: SPACING.md (16)
- 间距: SPACING.md (16)

卡片内容:
- 图标: 40x40vp 圆角矩形, Primary 色背景, 白色图标
- 名称: h3 样式, Text Primary
- 地址: body2 样式, Text Secondary
- 延迟标签: caption 样式, 绿色(<100ms)/黄色/红色背景
- 开关: 右侧, 48x28vp

**空状态 (Empty State)**
- 居中显示
- 插图: 120x120vp, 灰色线条风格
- 标题: h3 样式, "暂无 VPN 配置"
- 描述: body2 样式, "点击右下角按钮添加您的第一个配置"

**悬浮按钮 (FAB)**
- 位置: 右下角, 距边 24vp
- 尺寸: 56x56vp
- 形状: 圆形
- 颜色: Primary
- 图标: 白色 "+"
- 阴影: SHADOW.md

#### 交互设计
1. **卡片点击**: 进入编辑页
2. **开关切换**: 
   - 开启: 显示加载动画 → 连接成功: 卡片边框变为 Success 色
   - 关闭: 直接断开, 边框恢复默认
3. **卡片长按**: 弹出菜单 (编辑/删除/复制)
4. **左滑**: 显示删除按钮
5. **下拉刷新**: 刷新配置列表

---

### 2.2 配置编辑页 (ConfigEditPage.ets)

#### 布局结构
```
┌─────────────────────────────┐
│ [←] 编辑配置              [✓]│  ← Navigation Bar
├─────────────────────────────┤
│                             │
│ ┌─────────────────────────┐ │
│ │ 📋 基础信息              │ │  ← Section 1
│ │ ┌─────────────────────┐ │ │
│ │ │ 配置名称 *           │ │ │
│ │ │ [公司内网        ]   │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ 服务器地址 *         │ │ │
│ │ │ [vpn.example.com]   │ │ │
│ │ └─────────────────────┘ │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🔑 密钥信息              │ │  ← Section 2
│ │ ┌─────────────────────┐ │ │
│ │ │ 私钥 (PrivateKey) *  │ │ │
│ │ │ [••••••••••••••]   │ │ │
│ │ │ [👁 显示] [📋 粘贴]  │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ 公钥 (PublicKey) *   │ │ │
│ │ │ [••••••••••••••]   │ │ │
│ │ └─────────────────────┘ │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🌐 网络设置              │ │  ← Section 3
│ │ ┌─────────────────────┐ │ │
│ │ │ 本地 IP 地址         │ │ │
│ │ │ [10.0.0.2/24     ]   │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ DNS 服务器           │ │ │
│ │ │ [8.8.8.8, 1.1.1.1]   │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ MTU                 │ │ │
│ │ │ [1420            ]   │ │ │
│ │ └─────────────────────┘ │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ ⚙️ 高级设置              │ │  ← Section 4 (可折叠)
│ │ ┌─────────────────────┐ │ │
│ │ │ Allowed IPs          │ │ │
│ │ │ [0.0.0.0/0, ::/0 ]   │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ Persistent Keepalive │ │ │
│ │ │ [25              ]   │ │ │
│ │ └─────────────────────┘ │ │
│ │ ┌─────────────────────┐ │ │
│ │ │ PresharedKey         │ │ │
│ │ │ [可选            ]   │ │ │
│ │ └─────────────────────┘ │ │
│ └─────────────────────────┘ │
│                             │
│    [🗑️ 删除此配置]           │  ← Danger Button
│                             │
└─────────────────────────────┘
```

#### 组件规范

**Navigation Bar**
- 高度: 56vp
- 背景: Surface
- 左侧: 返回按钮 + 标题
- 右侧: 保存按钮 (✓)

**Section (分组)**
- 标题: overline 样式, Primary 色, 大写
- 背景: Surface
- 圆角: RADIUS.lg
- 内边距: SPACING.md
- 间距: SPACING.md

**Form Item (表单项)**
- 标签: caption 样式, Text Secondary
- 输入框: 
  - 高度: 48vp
  - 背景: Background
  - 圆角: RADIUS.md
  - 内边距: SPACING.md
  - 聚焦: 边框变为 Primary
- 辅助按钮: 图标按钮 (显示/隐藏、粘贴)

**Danger Button**
- 宽度: 100%
- 高度: 48vp
- 背景: transparent
- 文字: Danger 色
- 圆角: RADIUS.md

#### 交互设计
1. **字段验证**: 
   - 实时验证 (失去焦点时)
   - 错误提示: 红色边框 + 下方错误文字
   - 必填项标记: 红色 *
2. **密钥字段**:
   - 默认隐藏 (••••)
   - 点击 👁 切换显示
   - 点击 📋 从剪贴板粘贴
3. **保存按钮**:
   - 有修改时高亮
   - 点击验证所有字段
   - 验证通过返回上一页
4. **删除确认**:
   - 点击删除弹出对话框
   - 二次确认防止误操作

---

### 2.3 状态页 (StatusPage.ets)

#### 布局结构
```
┌─────────────────────────────┐
│ [←] 连接状态                │  ← Navigation Bar
├─────────────────────────────┤
│                             │
│         ┌─────────┐         │
│         │  🌐     │         │  ← Status Icon
│         │ 已连接   │         │
│         │ 45ms    │         │
│         └─────────┘         │
│                             │
│ ┌─────────────────────────┐ │
│ │    [流量图表区域]         │ │  ← Traffic Chart
│ │   ╱╲    ╱╲    ╱╲        │ │
│ │  ╱  ╲  ╱  ╲  ╱  ╲       │ │
│ │ ╱    ╲╱    ╲╱    ╲      │ │
│ └─────────────────────────┘ │
│                             │
│ ┌──────────┬──────────────┐ │
│ │   接收    │     发送      │ │  ← Stats Grid
│ │  1.2 GB  │    856 MB    │ │
│ └──────────┴──────────────┘ │
│                             │
│ ┌──────────┬──────────────┐ │
│ │  连接时长  │   最后握手    │ │
│ │ 02:34:18 │   15s 前     │ │
│ └──────────┴──────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 📊 详细统计              │ │  ← Details Section
│ │ 数据包接收: 1,234,567   │ │
│ │ 数据包发送: 987,654     │ │
│ │ 丢包率: 0.01%           │ │
│ └─────────────────────────┘ │
│                             │
│    [⏹ 断开连接]             │  ← Primary Button
│                             │
└─────────────────────────────┘
```

#### 组件规范

**Status Icon**
- 尺寸: 120x120vp
- 形状: 圆形
- 背景: Success 色 (已连接) / Danger 色 (断开)
- 图标: 白色, 48vp
- 动画: 呼吸灯效果 (已连接时)

**Traffic Chart**
- 高度: 200vp
- 背景: Surface
- 圆角: RADIUS.lg
- 类型: 面积图 (接收/发送双色)
- 颜色: Primary (接收) / Success (发送)
- 实时更新: 每秒

**Stats Grid**
- 2x2 网格
- 每个单元格:
  - 背景: Surface
  - 圆角: RADIUS.md
  - 标签: caption 样式
  - 数值: h2 样式

**Primary Button**
- 宽度: 90%
- 高度: 48vp
- 背景: Danger (断开连接)
- 文字: 白色
- 圆角: RADIUS.md

#### 交互设计
1. **实时更新**:
   - 流量数据每秒刷新
   - 图表平滑过渡动画
2. **断开连接**:
   - 点击按钮弹出确认对话框
   - 确认后断开并返回首页
3. **图表交互**:
   - 点击切换接收/发送/合并视图
   - 双指缩放查看历史

---

## 3. 组件库设计

### 3.1 公共组件

#### VpnConfigCard
```typescript
@Component
struct VpnConfigCard {
  @Prop config: WgConfig;
  @Prop isConnected: boolean;
  @Prop latency: number;
  onToggle: (isOn: boolean) => void;
  onEdit: () => void;
  onDelete: () => void;
  
  // 卡片布局实现
}
```

#### ConnectionStatus
```typescript
@Component
struct ConnectionStatus {
  @Prop status: 'connected' | 'connecting' | 'disconnected';
  @Prop configName: string;
  
  // 状态指示器实现
}
```

#### FormSection
```typescript
@Component
struct FormSection {
  @Prop title: string;
  @Prop icon?: Resource;
  @BuilderParam content: () => void;
  
  // 分组容器实现
}
```

#### EmptyState
```typescript
@Component
struct EmptyState {
  @Prop icon: Resource;
  @Prop title: string;
  @Prop description: string;
  @Prop actionText?: string;
  onAction?: () => void;
  
  // 空状态实现
}
```

#### TrafficChart
```typescript
@Component
struct TrafficChart {
  @Prop rxData: number[];
  @Prop txData: number[];
  @State showRx: boolean = true;
  @State showTx: boolean = true;
  
  // Canvas 图表实现
}
```

### 3.2 动画规范

#### 页面转场
```typescript
// 进入动画
PageTransitionEnter({ duration: 300, curve: Curve.EaseInOut })
  .slide(SlideEffect.Right)
  .opacity(0)

// 退出动画
PageTransitionExit({ duration: 300, curve: Curve.EaseInOut })
  .slide(SlideEffect.Right)
  .opacity(1)
```

#### 卡片交互
```typescript
// 按下效果
.scale(this.isPressed ? 0.98 : 1.0)
.animation({ duration: 150, curve: Curve.EaseInOut })

// 连接状态变化
.borderColor(this.isConnected ? COLORS.Success : COLORS.Divider)
.animation({ duration: 300, curve: Curve.Spring })
```

#### 加载动画
```typescript
// 圆形进度
LoadingProgress()
  .width(24)
  .height(24)
  .color(COLORS.Primary)

// 骨架屏
Skeleton()
  .width('100%')
  .height(72)
  .shimmer(true)
```

---

## 4. 资源文件规划

### 4.1 颜色资源 (resources/base/element/color.json)

```json
{
  "color": [
    { "name": "primary", "value": "#007DFF" },
    { "name": "primary_dark", "value": "#0056CC" },
    { "name": "success", "value": "#00B386" },
    { "name": "warning", "value": "#FF8800" },
    { "name": "danger", "value": "#FA2C2C" },
    { "name": "text_primary", "value": "#E6000000" },
    { "name": "text_secondary", "value": "#99000000" },
    { "name": "text_tertiary", "value": "#66000000" },
    { "name": "background", "value": "#F1F3F5" },
    { "name": "surface", "value": "#FFFFFF" },
    { "name": "divider", "value": "#1F000000" }
  ]
}
```

### 4.2 深色模式颜色 (resources/dark/element/color.json)

```json
{
  "color": [
    { "name": "text_primary", "value": "#E6FFFFFF" },
    { "name": "text_secondary", "value": "#99FFFFFF" },
    { "name": "text_tertiary", "value": "#66FFFFFF" },
    { "name": "background", "value": "#121212" },
    { "name": "surface", "value": "#1E1E1E" },
    { "name": "divider", "value": "#1FFFFFFF" }
  ]
}
```

### 4.3 尺寸资源 (resources/base/element/float.json)

```json
{
  "float": [
    { "name": "spacing_xs", "value": "4vp" },
    { "name": "spacing_sm", "value": "8vp" },
    { "name": "spacing_md", "value": "16vp" },
    { "name": "spacing_lg", "value": "24vp" },
    { "name": "spacing_xl", "value": "32vp" },
    { "name": "radius_sm", "value": "4vp" },
    { "name": "radius_md", "value": "8vp" },
    { "name": "radius_lg", "value": "12vp" },
    { "name": "radius_xl", "value": "16vp" },
    { "name": "header_height", "value": "56vp" },
    { "name": "card_height", "value": "72vp" },
    { "name": "button_height", "value": "48vp" },
    { "name": "fab_size", "value": "56vp" },
    { "name": "icon_size_sm", "value": "24vp" },
    { "name": "icon_size_md", "value": "40vp" },
    { "name": "icon_size_lg", "value": "48vp" }
  ]
}
```

### 4.4 字符串资源 (resources/base/element/string.json)

```json
{
  "string": [
    { "name": "app_name", "value": "WireGuard" },
    { "name": "page_title_main", "value": "WireGuard" },
    { "name": "page_title_edit", "value": "编辑配置" },
    { "name": "page_title_status", "value": "连接状态" },
    { "name": "status_connected", "value": "已连接" },
    { "name": "status_disconnected", "value": "未连接" },
    { "name": "status_connecting", "value": "连接中..." },
    { "name": "button_add_config", "value": "添加配置" },
    { "name": "button_disconnect", "value": "断开连接" },
    { "name": "button_save", "value": "保存" },
    { "name": "button_delete", "value": "删除" },
    { "name": "button_cancel", "value": "取消" },
    { "name": "empty_title", "value": "暂无 VPN 配置" },
    { "name": "empty_description", "value": "点击右下角按钮添加您的第一个配置" },
    { "name": "section_basic", "value": "基础信息" },
    { "name": "section_keys", "value": "密钥信息" },
    { "name": "section_network", "value": "网络设置" },
    { "name": "section_advanced", "value": "高级设置" },
    { "name": "field_name", "value": "配置名称" },
    { "name": "field_endpoint", "value": "服务器地址" },
    { "name": "field_private_key", "value": "私钥 (PrivateKey)" },
    { "name": "field_public_key", "value": "公钥 (PublicKey)" },
    { "name": "field_address", "value": "本地 IP 地址" },
    { "name": "field_dns", "value": "DNS 服务器" },
    { "name": "field_mtu", "value": "MTU" },
    { "name": "field_allowed_ips", "value": "Allowed IPs" },
    { "name": "field_keepalive", "value": "Persistent Keepalive" },
    { "name": "field_preshared_key", "value": "PresharedKey" },
    { "name": "hint_name", "value": "例如: 公司内网" },
    { "name": "hint_endpoint", "value": "例如: vpn.example.com:51820" },
    { "name": "hint_private_key", "value": "Base64 编码的 32 字节私钥" },
    { "name": "hint_public_key", "value": "服务器公钥" },
    { "name": "hint_address", "value": "例如: 10.0.0.2/24" },
    { "name": "hint_dns", "value": "例如: 8.8.8.8, 1.1.1.1" },
    { "name": "hint_mtu", "value": "默认 1420" },
    { "name": "hint_allowed_ips", "value": "例如: 0.0.0.0/0, ::/0" },
    { "name": "hint_keepalive", "value": "保活间隔秒数，默认 25" },
    { "name": "hint_preshared_key", "value": "可选预共享密钥" },
    { "name": "error_required", "value": "此项为必填项" },
    { "name": "error_invalid_endpoint", "value": "服务器地址格式不正确" },
    { "name": "error_invalid_key", "value": "密钥格式不正确" },
    { "name": "error_invalid_address", "value": "IP 地址格式不正确" },
    { "name": "dialog_delete_title", "value": "确认删除" },
    { "name": "dialog_delete_message", "value": "确定要删除此配置吗？此操作不可撤销。" },
    { "name": "dialog_disconnect_title", "value": "确认断开" },
    { "name": "dialog_disconnect_message", "value": "确定要断开当前连接吗？" },
    { "name": "toast_save_success", "value": "配置已保存" },
    { "name": "toast_delete_success", "value": "配置已删除" },
    { "name": "toast_connect_success", "value": "VPN 连接成功" },
    { "name": "toast_disconnect_success", "value": "VPN 已断开" },
    { "name": "toast_connect_failed", "value": "VPN 连接失败" },
    { "name": "stats_rx", "value": "接收" },
    { "name": "stats_tx", "value": "发送" },
    { "name": "stats_duration", "value": "连接时长" },
    { "name": "stats_handshake", "value": "最后握手" },
    { "name": "stats_packets_rx", "value": "数据包接收" },
    { "name": "stats_packets_tx", "value": "数据包发送" },
    { "name": "stats_loss", "value": "丢包率" }
  ]
}
```

---

## 5. 文件结构规划

```
entry/src/main/ets/
├── common/
│   ├── Constants.ets          # 常量定义
│   ├── DesignSystem.ets       # 设计系统 (颜色、间距、字体)
│   └── Utils.ets              # 工具函数
├── components/
│   ├── VpnConfigCard.ets      # 配置卡片
│   ├── ConnectionStatus.ets   # 连接状态指示器
│   ├── FormSection.ets        # 表单分组
│   ├── FormInput.ets          # 表单输入框
│   ├── EmptyState.ets         # 空状态
│   ├── TrafficChart.ets       # 流量图表
│   ├── StatsCard.ets          # 统计卡片
│   ├── LoadingOverlay.ets     # 加载遮罩
│   └── ConfirmDialog.ets      # 确认对话框
├── pages/
│   ├── Index.ets              # 首页
│   ├── ConfigEditPage.ets     # 配置编辑页
│   └── StatusPage.ets         # 状态页
├── service/
│   └── ConfigManager.ts       # 配置管理
├── model/
│   └── WgConfig.ts            # 数据模型
└── vpnextension/
    └── WireGuardVpnAbility.ets # VPN 扩展能力
```

---

## 6. 实现优先级

### Phase 1: 基础设计系统
1. 创建 `DesignSystem.ets` 定义颜色、间距、字体
2. 更新资源文件 (color.json, float.json, string.json)
3. 实现基础组件 (FormSection, FormInput)

### Phase 2: 首页重构
1. 实现 `VpnConfigCard` 组件
2. 实现 `EmptyState` 组件
3. 重构 `Index.ets` 页面布局
4. 添加 FAB 按钮

### Phase 3: 配置编辑页重构
1. 实现表单分组和折叠面板
2. 添加字段验证
3. 实现密钥显示/隐藏
4. 添加删除确认对话框

### Phase 4: 状态页重构
1. 实现 `TrafficChart` 组件
2. 实现 `StatsCard` 组件
3. 添加实时数据更新
4. 实现断开连接确认

### Phase 5: 动画和交互
1. 添加页面转场动画
2. 实现卡片按压效果
3. 添加连接状态动画
4. 实现列表项滑动删除

---

## 7. 注意事项

1. **性能优化**:
   - 列表使用 `LazyForEach` 替代 `ForEach`
   - 图表使用 `Canvas` 手动绘制，避免频繁重排
   - 图片资源使用适当分辨率

2. **无障碍支持**:
   - 为所有交互元素添加 `accessibilityText`
   - 确保颜色对比度符合 WCAG 标准
   - 支持屏幕阅读器

3. **国际化**:
   - 所有文本使用字符串资源
   - 支持 RTL 布局 (阿拉伯语等)
   - 日期/数字格式本地化

4. **深色模式**:
   - 使用资源限定符 `dark/`
   - 测试所有页面的深色显示效果
   - 图片资源提供深色版本

5. **适配不同屏幕**:
   - 使用响应式布局 (百分比、栅格)
   - 平板设备支持双栏布局
   - 折叠屏适配

---

*此设计方案遵循 HarmonyOS 设计规范，可根据实际需求调整。*
