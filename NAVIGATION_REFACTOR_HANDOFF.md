# 交接文档：多端导航重构（router → Navigation/NavPathStack）

> 这是商用级 UI 重塑**唯一剩下的大件**，本文件供**新会话**从零高效接手。作者上一会话已把其余全部做完并真机验证（见文末"已完成"）。

## 0. 一句话任务

把整个 App 从**已废弃的 `@ohos.router`**（`router.pushUrl/back/getParams`）迁移到官方推荐的 **`Navigation` + `NavPathStack`**，用 `NavigationMode.Auto` 实现平板/2in1 上的**分栏（split）多端适配**，同时消除 deprecated 警告。这是审计里"多端适配第一短板"。

## 1. 为什么单独开一段做

- 要动**全部 7 个页面**：`@Entry` → `@Component`、路由表、参数传递、返回逻辑全换。
- **运行期路由 bug 编译查不出**，必须真机逐流程验证（打开/返回/带参/分栏）。
- 一改就可能全 App 无法导航，所以务必**每步保持可编译**、小步提交、真机验证后再下一步。

## 2. 当前 router 用法全清单（grep 实测，逐行改）

| 文件 | 行 | 现状 | 改成 |
|---|---|---|---|
| Index.ets | 5 | `import { router }` | 删；改用 `NavPathStack` |
| Index.ets | 229/238/393 | `router.pushUrl({url:'pages/ImportConfigPage'})` | `this.pageStack.pushPath({ name:'ImportConfig' })` |
| Index.ets | 247 | `router.pushUrl({url:'pages/ConfigEditPage'})` | `pushPath({ name:'ConfigEdit' })` |
| Index.ets | 286/319 | `router.pushUrl({url:'pages/TunnelDetailPage', params:{id:cfg.id}})` | `pushPath({ name:'TunnelDetail', param: cfg.id })`（仅 compact 断点；medium/expanded 仍走内联 `selectedConfigId`）|
| Index.ets | 358/470/496 | `router.pushUrl({url:'pages/SettingsPage'})` | `pushPath({ name:'Settings' })` |
| SettingsPage.ets | 108 | `router.back()` | `this.pageStack.pop()`（@Consume）|
| SettingsPage.ets | 175/178/181 | `router.pushUrl({url:'pages/AboutPage'})` | `pushPath({ name:'About' })` |
| AboutPage.ets | 16 | `router.back()` | `pop()` |
| ImportConfigPage.ets | 33 | `router.pushUrl({url:'pages/ConfigPreviewPage', params:{...}})`（扫码/文件/剪贴板解析后跳预览，**带 config 数据**）| `pushPath({ name:'ConfigPreview', param: <ParseResult/config> })` |
| ImportConfigPage.ets | 201 | `router.back()` | `pop()` |
| ImportConfigPage.ets | 261 | `router.pushUrl({url:'pages/ConfigEditPage'})` | `pushPath({ name:'ConfigEdit' })` |
| ConfigPreviewPage.ets | 27 | `router.getParams()` 读 config | 改为 `@Prop` 接收 param |
| ConfigPreviewPage.ets | 82/113 | `router.back()` | `pop()` |
| ConfigPreviewPage.ets | 243 | `router.pushUrl({url:'pages/ConfigEditPage', params:{config:this.config}})` | `pushPath({ name:'ConfigEdit', param: this.config })` |
| ConfigEditPage.ets | 52 | `router.getParams()` 读 config/id（编辑态）| `@Prop` 接收 param |
| ConfigEditPage.ets | 118/124/216 | `router.back()` | `pop()`（保存成功后 pop 回 Index，Index 要刷新列表）|
| TunnelDetailPage.ets | 11 | `router.getParams()` 读 id | `@Prop configId` |
| TunnelDetailPage.ets | 26 | `router.back()` | `pop()` |

> ⚠️ 注意 Index.ets 行号是重构前的，改的过程中会漂移，以符号/上下文定位。

## 3. 推荐架构

**Index 作为唯一 `@Entry`，同时是 Navigation 宿主：**

```ts
// Index.ets
@Entry @Component struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  // ...原有 @State...

  build() {
    Navigation(this.pageStack) {
      // 原来的 Stack{ compact/medium/expanded } 整块作为 Navigation 内容（左栏/根页）
      Stack() { /* 原 CompactLayout/MediumLayout/ExpandedLayout 三选一 */ }
        .onAreaChange(...)  // 保留
    }
    .navDestination(PageMap)          // 顶层 @Builder，不能内联 lambda（ArkTS 规则）
    .mode(NavigationMode.Auto)         // <600vp 单栏，>=600vp 自动分栏
    .hideTitleBar(true)                // 各页有自定义 header
  }
}

// 顶层 @Builder（不在 struct 内），把路由名映射到页面组件
@Builder
function PageMap(name: string, param: Object) {
  if (name === 'Settings') { NavDestination() { SettingsPage() }.hideTitleBar(true) }
  else if (name === 'About') { NavDestination() { AboutPage() }.hideTitleBar(true) }
  else if (name === 'Import') { NavDestination() { ImportConfigPage() }.hideTitleBar(true) }
  else if (name === 'ConfigEdit') { NavDestination() { ConfigEditPage({ initialConfig: param as ... }) }.hideTitleBar(true) }
  else if (name === 'ConfigPreview') { NavDestination() { ConfigPreviewPage({ parsed: param as ... }) }.hideTitleBar(true) }
  else if (name === 'TunnelDetail') { NavDestination() { TunnelDetailPanel({ configId: param as string }) }.hideTitleBar(true) }
}
```

**各二级页**：`@Entry` → `@Component`；删 `pageTransition()`（Navigation 自带转场）；参数改 `@Prop` 从 PageMap 传入；返回用 `@Consume('pageStack') pageStack: NavPathStack` 然后 `this.pageStack.pop()`。

## 4. 关键坑（务必读）

1. **Index 已有手写 master-detail**：medium/expanded 断点下 Index 自己就是 `list + TunnelDetailPanel` 双栏（`selectedConfigId` 内联，不走路由）。`NavigationMode.Auto` 在宽屏也会分栏 → **可能和 Index 内联双栏打架**（Index 内容被塞进更窄的左栏，medium/expanded 布局会挤）。两种解法，真机对比后选：
   - **A（稳）**：Navigation 用 `NavigationMode.Stack`（不分栏），只替换 router、保留 Index 现有响应式双栏。多端能力已在 Index，二级页全屏可接受。**风险最低，先上这个能编译能用的版本。**
   - **B（更符合"分栏"）**：把 Index 的 medium/expanded 内联 detail **删掉**，改由 Navigation 分栏统一承载（home 列表当根页、点隧道 pushPath TunnelDetail 到右栏）。更干净但改动更大、要重测所有断点。
   - 建议：**先 A 落地验证通过并提交**，再评估要不要上 B。
2. `navDestination` 必须传**顶层 `@Builder` 函数引用**，不能内联 lambda（ArkTS 报错，见 harmonyos 规则）。
3. **参数传递**：`pushPath({name, param})` 的 param 经 PageMap 的第二个入参给到页面 `@Prop`。ConfigEdit/Preview 传的是对象（WgConfig/ParseResult），TunnelDetail/传 id 字符串。注意 ArkTS 不能传裸对象字面量当 `Object`，用具体类型。
4. **返回后刷新**：Index 现在靠 `onPageShow()` 从二级页 back 回来刷新列表（`loadConfigs`）。Navigation 下 `onPageShow` 不再触发——改用 `pushPath(..., onPop)` 回调，或 Index `onShown`/在 pop 后主动刷新。ConfigEdit 保存后 pop 回 Index 必须让列表刷新。
5. **`TunnelDetailPage` vs `TunnelDetailPanel`**：TunnelDetailPage 只是包了个 header + TunnelDetailPanel。迁移后可直接在 PageMap 里用 `TunnelDetailPanel`（它已接受 `configId`），TunnelDetailPage 可删。
6. **main_pages.json**（`entry/src/main/resources/base/profile/main_pages.json`）：二级页不再是 `@Entry` 后要从里面**移除**，只留 `"pages/Index"`，否则打包可能报"找不到 @Entry"。
7. 各页顶部 `import { router } from '@kit.ArkUI'` 删掉；`common`/其它 import 保留。
8. ArkTS 严格模式通用坑见 `.claude/rules/harmonyos.md`（无 any、无对象字面量当类型、箭头函数、`getContext` 已弃用用 `getUIContext().getHostContext()` 等）。

## 5. 构建 / 部署 / 真机验证

**构建**（Windows PowerShell，项目根 `C:\Project\HarmonyWireguard`）：
```powershell
$env:DEVECO_SDK_HOME = "C:\Program Files\Huawei\DevEco Studio\sdk"
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default -p module=entry@default assembleHap --no-daemon
```
产物：`entry\build\default\outputs\default\entry-default-signed.hap`

**部署+截图**（真机是云端 HUAWEI MateBook Pro 2in1，`hdc tconn 172.16.100.1:36597`，App 是浮动窗口）：
```powershell
hdc shell "aa force-stop com.javazeroo.harmonywireguard"
hdc install -r <hap>
hdc shell "aa start -b com.javazeroo.harmonywireguard -a EntryAbility"
hdc shell "aa start -b com.javazeroo.harmonywireguard -a EntryAbility"   # 再来一次把 App 提到最前
hdc shell "snapshot_display -f /data/local/tmp/x.jpeg"
# 用 PowerShell（不是 Git Bash，路径会坏）拉图： hdc file recv /data/local/tmp/x.jpeg <本地>
```
- **验证前先让用户在 DevEco 里"断开设备"**（别关 IDE），否则 DevEco 抢 hdc、连接反复掉、App 窗口被 IDE 盖住。
- 坐标点击 `uitest uiInput click X Y`（真机 px = 截图显示坐标 × 1.56）。参考位：设置入口=主页右上 list_bullet(~2549,405)、FAB(~2519,1585)、隧道开关(~2505,1125)。
- **必测流程**：主页→设置→关于→返回；主页→FAB 导入→（扫码/文件/剪贴板→预览带参→编辑）；主页→点隧道→详情带参→返回；保存配置后返回主页列表刷新；窄/宽窗口各测一遍（宽屏看分栏是否合理）；深浅色各扫一眼。

## 6. 已完成（本 App 现状，`main` 已推到 origin，HEAD=c7eb2d8 附近）

核心链路已通（握手/数据面/路由，真机端到端可用）；真实状态+流量（native getStatus + commonEvent 跨进程）；商用级视觉（Hero 徽标+柔光+雷达脉冲+出场转场、列表图标容器+投影+hover、详情真 Canvas 折线、全局卡片投影）；**深色模式全链路**（设置分段选择器+preferences 持久化+启动应用，真机逐屏验证）；关于/导入页精致化；2in1 hover；规范清理（删死代码/重复组件/px2vp）。详见记忆库 `ui_commercial_redesign_state.md`、`vpn_extension_debugging.md`、`sdk_symbol_availability.md`。

## 7. 参考
- harmonyos-development skill 的 **Navigation / NavPathStack** 章节（pushPath/pop/setInterception、Split/Auto、navDestination 用顶层 @Builder）。
- `.claude/rules/harmonyos.md`：ArkTS 严格模式约束。
- 官方：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-navigation
