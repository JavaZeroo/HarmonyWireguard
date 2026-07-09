import { vpnExtension } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { configManager } from '../service/ConfigManager';
import type { WgConfig, TunnelStatusType, WgStatusPayload } from '../model/WgConfig';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';
import { ConfigEditPage } from './ConfigEditPage';
import { ConfigPreviewPage } from './ConfigPreviewPage';
import { TunnelDetailPage } from './TunnelDetailPage';
import { APP_CONSTANTS } from '../common/Constants';
import { SPACING, TYPOGRAPHY, Breakpoint, getBreakpoint, getString } from '../common/DesignSystem';
import { formatBytes } from '../common/Formatters';
import { shouldApplyToggle, ToggleContext } from '../common/Utils';
import { ConnectionHeroCard } from '../components/tunnel/ConnectionHeroCard';
import { TunnelListItem } from '../components/tunnel/TunnelListItem';
import { EmptyState } from '../components/common/EmptyState';
import { DiagnosticSummaryCard } from '../components/tunnel/DiagnosticSummaryCard';
import type { DiagnosticItem } from '../model/WgConfig';
import { tunnelRuntimeService } from '../service/TunnelRuntimeService';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';
import { ImportActions } from '../service/ImportActions';
import { DialogHelper } from '../common/DialogHelper';

const TAG = 'IndexPage';

// Navigation 目的地路由表（顶层 @Builder，navDestination 要求函数引用，不能内联 lambda）
@Builder
function PageMap(name: string, param: Object) {
  if (name === 'About') {
    NavDestination() { AboutPage() }.hideTitleBar(true)
  } else if (name === 'ConfigEdit') {
    NavDestination() { ConfigEditPage({ navParam: param }) }.hideTitleBar(true)
  } else if (name === 'ConfigPreview') {
    NavDestination() { ConfigPreviewPage({ navParam: param }) }.hideTitleBar(true)
  } else if (name === 'TunnelDetail') {
    NavDestination() { TunnelDetailPage({ navConfigId: param as string }) }.hideTitleBar(true)
  }
}

function createWant(config: WgConfig): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    moduleName: 'entry',
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME,
    parameters: { wgConfig: JSON.stringify(config) }
  };
}

function createStopWant(): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    moduleName: 'entry',
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME
  };
}

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @State configs: WgConfig[] = [];
  @State activeConfigId: string = '';
  @State activeStatus: TunnelStatusType = 'disconnected';
  @State connectingId: string = '';
  @State rxBytes: number = 0;
  @State txBytes: number = 0;
  @State lastHandshakeAt: number = -1;
  @State selectedConfigId: string = '';
  @State diagnostics: DiagnosticItem[] = [];
  @State breakpoint: Breakpoint = Breakpoint.COMPACT;
  @State windowWidth: number = 360;
  @State currentTabIndex: number = 0;
  @State miniExpanded: boolean = false;
  // 手机端隧道详情：改用 bindContentCover 全屏展开（一镜到底），不走 Navigation push
  @State detailCoverShow: boolean = false;
  @State detailCoverId: string = '';
  // FAB 添加菜单是否展开：驱动 “+” 旋转成 “×”
  @State fabMenuOpen: boolean = false;

  private unsubscribe?: () => void;
  private statusSubscriber: commonEventManager.CommonEventSubscriber | null = null;
  private lastConnLogged: number = -1;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    configManager.init(ctx);
    this.loadConfigs();
    this.updateBreakpoint();

    this.unsubscribe = tunnelRuntimeService.subscribe((states) => {
      if (this.activeConfigId) {
        const state = states.get(this.activeConfigId);
        if (state) {
          this.activeStatus = state.status;
          this.rxBytes = state.rxBytes;
          this.txBytes = state.txBytes;
          this.lastHandshakeAt = state.lastHandshakeAt || -1;
        }
      }
    });

    this.setupStatusSubscriber();

    // 二级页(导入/编辑/预览/详情)通过 pop 回到首页(navBar)时刷新配置列表，
    // 因为 Navigation 内的 NavDestination 切换不会触发本页 onPageShow。
    this.pageStack.setInterception({
      didShow: (from: NavDestinationContext | NavBar, to: NavDestinationContext | NavBar,
                operation: NavigationOperation, isAnimated: boolean) => {
        if (typeof to === 'string') {
          this.loadConfigs();
        }
      }
    });
  }

  aboutToDisappear(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
    }
    this.teardownStatusSubscriber();
  }

  // 订阅扩展子进程回传的实时状态/流量事件，喂给 TunnelRuntimeService
  private setupStatusSubscriber(): void {
    if (this.statusSubscriber) {
      return;
    }
    const info: commonEventManager.CommonEventSubscribeInfo = {
      events: [APP_CONSTANTS.VPN_STATUS_EVENT]
    };
    commonEventManager.createSubscriber(info,
      (err: BusinessError, subscriber: commonEventManager.CommonEventSubscriber) => {
        if (err) {
          hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'createSubscriber failed: %{public}d', err.code);
          return;
        }
        this.statusSubscriber = subscriber;
        commonEventManager.subscribe(subscriber,
          (subErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (subErr) {
              return;
            }
            this.onStatusEvent(data);
          });
      });
  }

  private teardownStatusSubscriber(): void {
    if (this.statusSubscriber) {
      commonEventManager.unsubscribe(this.statusSubscriber);
      this.statusSubscriber = null;
    }
  }

  private onStatusEvent(data: commonEventManager.CommonEventData): void {
    const params = data.parameters;
    const body: string | undefined = data.data;
    if (!params || !body) {
      return;
    }
    const configId = params['configId'] as string;
    if (!configId) {
      return;
    }
    let payload: WgStatusPayload;
    try {
      payload = JSON.parse(body) as WgStatusPayload;
    } catch (e) {
      return;
    }
    // 只在连接态翻转时打点，避免每 1.5s 刷屏
    const connFlag: number = payload.connected ? 1 : 0;
    if (connFlag !== this.lastConnLogged) {
      this.lastConnLogged = connFlag;
      hilog.info(APP_CONSTANTS.DOMAIN, TAG,
        'VPN status: connected=%{public}d ageSec=%{public}d rx=%{public}d tx=%{public}d',
        connFlag, payload.handshakeAgeSec, payload.rxBytes, payload.txBytes);
    }
    tunnelRuntimeService.applyStatus(configId, payload);
  }

  onPageShow(): void {
    // 应用回到前台时刷新列表(二级页 pop 的刷新由 setInterception 处理)
    this.loadConfigs();
  }

  private updateBreakpoint(): void {
    try {
      this.windowWidth = AppStorage.get<number>('windowWidth') ?? 360;
    } catch {
      this.windowWidth = 360;
    }
    this.breakpoint = getBreakpoint(this.windowWidth);
  }

  loadConfigs(): void {
    this.configs = configManager.getAllConfigs();
  }

  getActiveConfig(): WgConfig | undefined {
    if (!this.activeConfigId) return undefined;
    return this.configs.find(c => c.id === this.activeConfigId);
  }

  getSelectedConfig(): WgConfig | undefined {
    if (!this.selectedConfigId) return undefined;
    return this.configs.find(c => c.id === this.selectedConfigId);
  }

  async toggleVpn(config: WgConfig, enable: boolean): Promise<void> {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG,
      '>>> toggleVpn[v3] config=%{public}s enable=%{public}s',
      config.name, String(enable));
    // 防抖/防冲突：过滤伪/矛盾的开关调用（修复“连上又立刻断开”）。
    // 判定逻辑抽到 Utils.shouldApplyToggle，便于单元测试覆盖。
    const toggleCtx: ToggleContext = {
      activeConfigId: this.activeConfigId,
      connectingId: this.connectingId,
      activeStatus: this.activeStatus
    };
    if (!shouldApplyToggle(config.id, enable, toggleCtx)) {
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'toggleVpn ignored (guard): enable=%{public}s', String(enable));
      return;
    }
    if (enable) {
      this.connectingId = config.id;
      this.activeStatus = 'connecting';
      try {
        // 系统 VPN 授权对话框会丢掉 want.parameters，所以把要用的配置 id 写到 prefs
        configManager.setActiveConfigId(config.id);
        const want = createWant(config);
        hilog.info(APP_CONSTANTS.DOMAIN, TAG,
          'startVpnExtensionAbility: bundle=%{public}s module=%{public}s ability=%{public}s configId=%{public}s',
          want.bundleName ?? '', want.moduleName ?? '', want.abilityName ?? '', config.id);
        await vpnExtension.startVpnExtensionAbility(want);
        this.activeConfigId = config.id;
        // 只代表"扩展已拉起"，真正的 connected 由扩展握手成功后经事件回传
        this.activeStatus = 'connecting';
        tunnelRuntimeService.setStatus(config.id, 'connecting');
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN extension started for %{public}s', config.name);
      } catch (err) {
        const e = err as BusinessError;
        const code = e?.code !== undefined ? String(e.code) : '?';
        const msg = e?.message ?? String(err);
        this.activeStatus = 'failed';
        tunnelRuntimeService.setStatus(config.id, 'failed', msg);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG,
          'Failed to start VPN: code=%{public}s msg=%{public}s', code, msg);
      }
      this.connectingId = '';
    } else {
      try {
        await vpnExtension.stopVpnExtensionAbility(createStopWant());
        this.activeStatus = 'disconnected';
        tunnelRuntimeService.setStatus(config.id, 'disconnected');
        if (this.activeConfigId === config.id) {
          this.activeConfigId = '';
          this.rxBytes = 0;
          this.txBytes = 0;
          this.lastHandshakeAt = -1;
        }
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN stopped');
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to stop VPN: %{public}s', msg);
      }
    }
  }

  @Builder
  EmptyActionBuilder() {
    Column({ space: SPACING.sm }) {
      Button(getString($r('app.string.button_scan_qr')))
        .width('60%')
        .height(44)
        .onClick(() => {
          ImportActions.scanQR(this.getUIContext(), this.pageStack);
        })

      Button(getString($r('app.string.button_import_file')))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          ImportActions.fromFile(this.getUIContext(), this.pageStack);
        })

      Button(getString($r('app.string.button_create_manual')))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          ImportActions.manualCreate(this.pageStack);
        })
    }
    .width('100%')
  }

  // FAB「添加配置」菜单项：改为下拉菜单（沉浸光感原生 Menu），不再整页跳转。
  private importMenuItems(): MenuElement[] {
    const ctx = this.getUIContext();
    const stack = this.pageStack;
    return [
      {
        value: getString($r('app.string.button_scan_qr')),
        action: () => { ImportActions.scanQR(ctx, stack); }
      },
      {
        value: getString($r('app.string.button_import_file')),
        action: () => { ImportActions.fromFile(ctx, stack); }
      },
      {
        value: getString($r('app.string.button_import_clipboard')),
        action: () => { ImportActions.fromClipboard(ctx, stack); }
      },
      {
        value: getString($r('app.string.button_create_manual')),
        action: () => { ImportActions.manualCreate(stack); }
      }
    ];
  }

  private statusColorRes(): ResourceColor {
    switch (this.activeStatus) {
      case 'connected':
        return $r('app.color.success');
      case 'connecting':
        return $r('app.color.primary');
      case 'failed':
        return $r('app.color.danger');
      default:
        return $r('app.color.text_tertiary');
    }
  }

  private statusTextLabel(): string {
    switch (this.activeStatus) {
      case 'connected':
        return getString($r('app.string.status_connected'));
      case 'connecting':
        return getString($r('app.string.status_connecting'));
      case 'failed':
        return getString($r('app.string.status_failed'));
      default:
        return getString($r('app.string.status_disconnected'));
    }
  }

  // 手机端内容从钉住的玻璃标题栏下穿过 → 顶部留白；平板/2in1 标题栏在上方不重叠。
  private topContentClearance(): number {
    return this.breakpoint === Breakpoint.COMPACT ? 44 : SPACING.xs;
  }

  // 底部留白避开悬浮 Dock（Tab 胶囊 / 连接中 MiniBar，展开时更高）。
  private bottomContentClearance(): number {
    if (this.breakpoint !== Breakpoint.COMPACT) {
      return SPACING.lg;
    }
    if (this.activeConfigId === '') {
      return 92;
    }
    return this.miniExpanded ? 256 : 152;
  }

  // 「配置」分区标题：标题 + 数量，符合 HarmonyOS 列表分组头样式。
  @Builder
  ConfigSectionHeader() {
    Row() {
      Text(getString($r('app.string.section_configs')))
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(TYPOGRAPHY.title_sm.weight)
        .fontColor($r('app.color.text_primary'))
      Text(this.configs.length.toString())
        .fontSize(TYPOGRAPHY.body_sm.size)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ left: SPACING.sm })
      Blank()
    }
    .width('100%')
    .padding({ top: SPACING.xs, bottom: SPACING.xs })
  }

  @Builder
  HeroListItem() {
    ConnectionHeroCard({
      status: this.activeStatus,
      tunnelName: this.getActiveConfig()?.name || '',
      endpoint: this.getActiveConfig()?.endpoint || '',
      lastHandshakeAt: this.lastHandshakeAt,
      rxBytes: this.rxBytes,
      txBytes: this.txBytes,
      onPrimaryAction: () => {
        if (this.activeStatus === 'connected') {
          const cfg = this.getActiveConfig();
          if (cfg) this.toggleVpn(cfg, false);
        } else if (this.activeStatus === 'disconnected' || this.activeStatus === 'failed') {
          const cfg = this.getActiveConfig();
          if (cfg) this.toggleVpn(cfg, true);
        }
      },
      onDetail: () => {
        this.openActiveDetail();
      }
    })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
      .combine(TransitionEffect.translate({ y: -10 }))
      .animation({ duration: 350, curve: Curve.FastOutSlowIn }))
  }

  // 隧道页内容：HarmonyOS 惯用 List（统一 8vp 栅格间距 + 页边距），
  // 依次为当前连接 Hero、快速诊断、配置分组标题、配置卡片列表。
  @Builder
  ConfigListContent() {
    if (this.configs.length === 0) {
      Column() {
        EmptyState({
          icon: 'wifi_slash',
          title: getString($r('app.string.empty_config_title')),
          description: getString($r('app.string.empty_config_desc'))
        }) {
          this.EmptyActionBuilder()
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: SPACING.lg, right: SPACING.lg, top: this.breakpoint === Breakpoint.COMPACT ? 52 : 0 })
    } else {
      List({ space: SPACING.md }) {
        ListItem() {
          Row().width('100%').height(this.topContentClearance())
        }

        if (this.activeConfigId) {
          ListItem() {
            this.HeroListItem()
          }
        }

        if (this.diagnostics.length > 0) {
          ListItem() {
            DiagnosticSummaryCard({ items: this.diagnostics })
          }
        }

        ListItem() {
          this.ConfigSectionHeader()
        }

        ForEach(this.configs, (config: WgConfig) => {
          // 一镜到底：详情 Cover 展开时把源卡片从列表移除，使其作为共享元素
          // “消失端”与 Cover“出现端”配对形变；关闭时源卡重新出现，Cover 收回到卡片。
          // 列表此时被全屏 Cover 遮住，移除引起的回流不可见。
          if (!(this.detailCoverShow && this.detailCoverId === config.id)) {
            ListItem() {
              TunnelListItem({
                config: config,
                status: config.id === this.activeConfigId ? this.activeStatus : 'disconnected',
                selected: config.id === this.selectedConfigId || config.id === this.activeConfigId,
                sharedTag: this.breakpoint === Breakpoint.COMPACT ? ('detail_' + config.id) : '',
                onSelect: () => {
                  this.openDetail(config.id);
                },
                onConnect: () => {
                  this.toggleVpn(config, true);
                },
                onDisconnect: () => {
                  this.toggleVpn(config, false);
                }
              })
            }
          }
        }, (config: WgConfig) => config.id)

        ListItem() {
          Row().width('100%').height(this.bottomContentClearance())
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: SPACING.md, right: SPACING.md })
    }
  }

  // 光感玻璃标题栏：品牌标识 + 毛玻璃材质，替代原纯色标题栏；手机端内容从其下穿过。
  @Builder
  TopBar() {
    Row() {
      SymbolGlyph($r('sys.symbol.wifi'))
        .fontSize(22)
        .fontColor([$r('app.color.primary')])
      Text(getString($r('app.string.page_home')))
        .fontSize(TYPOGRAPHY.title_md.size)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: SPACING.sm })
    }
    .width('100%')
    .height(52)
    .padding({ left: SPACING.lg, right: SPACING.lg })
    .backgroundColor($r('app.color.glass_bar'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
  }

  @Builder
  Fab() {
    Button() {
      Text('+')
        .fontSize(24)
        .fontColor('#FFFFFF')
        // 菜单展开时 “+” 旋转 45° 成 “×”，收起还原
        .rotate({ angle: this.fabMenuOpen ? 45 : 0 })
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })
    }
    .width(56)
    .height(56)
    .backgroundColor($r('app.color.primary'))
    .borderRadius(28)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.20)', offsetY: 4 })
    // 上抬避开底部悬浮 Dock（Tab 胶囊 / 连接中 MiniBar，展开时更高）
    .margin({ right: SPACING.md, bottom: this.breakpoint === Breakpoint.COMPACT ? (this.activeConfigId !== '' ? (this.miniExpanded ? 264 : 160) : 72) : SPACING.lg })
    .hoverEffect(HoverEffect.Highlight)
    .bindMenu(this.importMenuItems(), {
      onAppear: () => {
        this.fabMenuOpen = true;
      },
      onDisappear: () => {
        this.fabMenuOpen = false;
      }
    })
  }

  // 手机整屏：内容从光感玻璃标题栏下穿过，FAB 悬浮右下。
  @Builder
  CompactLayout() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // List 自带滚动，内容从玻璃标题栏下穿过（顶部留白由 topContentClearance 处理）
      this.ConfigListContent()

      if (this.configs.length > 0) {
        this.Fab()
      }

      // 光感玻璃标题栏钉在顶部
      Column() {
        this.TopBar()
      }
      .width('100%')
      .position({ x: 0, y: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  DetailPlaceholder() {
    Column() {
      Text(getString($r('app.string.hint_select_config_detail')))
        .fontSize(TYPOGRAPHY.body_lg.size)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.background'))
  }

  // 主栏宽度随断点/窗口放大（占比思想）：折叠屏窄一档，超大屏（≥1440vp）更宽。
  private masterWidth(): number {
    if (this.breakpoint === Breakpoint.MEDIUM) {
      return 320;
    }
    return this.windowWidth >= 1440 ? 400 : 360;
  }

  // 平板 / 折叠屏 / 2in1：顶部全宽光感标题栏 + 下方左“主”栏右详情。
  // 全宽标题栏解决全屏时标题被挤在窄列里的问题；未手动选中时回退到当前连接的隧道。
  @Builder
  SplitLayout(masterWidth: number) {
    Column() {
      this.TopBar()

      Row() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          this.ConfigListContent()

          if (this.configs.length > 0) {
            this.Fab()
          }
        }
        .width(masterWidth)
        .height('100%')
        .backgroundColor($r('app.color.background'))

        Divider()
          .vertical(true)
          .strokeWidth(1)
          .color($r('app.color.divider'))

        if (this.selectedConfigId !== '') {
          TunnelDetailPanel({
            configId: this.selectedConfigId,
            contentMaxWidth: 720,
            onEdit: () => {
              this.editConfig(this.selectedConfigId);
            },
            onDelete: () => {
              this.requestDeleteConfig(this.selectedConfigId);
            }
          })
            .layoutWeight(1)
        } else if (this.activeConfigId !== '') {
          TunnelDetailPanel({
            configId: this.activeConfigId,
            contentMaxWidth: 720,
            onEdit: () => {
              this.editConfig(this.activeConfigId);
            },
            onDelete: () => {
              this.requestDeleteConfig(this.activeConfigId);
            }
          })
            .layoutWeight(1)
        } else {
          Stack() {
            this.DetailPlaceholder()
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  // 手机底部胶囊项：未选中仅图标，选中态展开为品牌色填充胶囊（图标 + 文字）。
  @Builder
  CapsuleItemH(index: number, label: string, icon: Resource) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentTabIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary')])
      if (this.currentTabIndex === index) {
        Text(label)
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .maxLines(1)
      }
    }
    .justifyContent(FlexAlign.Center)
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.currentTabIndex === index ? $r('app.color.primary_bg') : Color.Transparent)
    .borderRadius(22)
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.currentTabIndex = index;
      });
    })
  }

  // 平板/2in1 侧栏胶囊项：图标 + 文字竖排，选中态填充胶囊。
  @Builder
  CapsuleItemV(index: number, label: string, icon: Resource) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentTabIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary')])
      Text(label)
        .fontSize(TYPOGRAPHY.caption.size)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(60)
    .height(52)
    .backgroundColor(this.currentTabIndex === index ? $r('app.color.primary_bg') : Color.Transparent)
    .borderRadius(16)
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.currentTabIndex = index;
      });
    })
  }

  // 手机底部横向胶囊 Tab 栏
  @Builder
  TabCapsuleH() {
    Row({ space: 4 }) {
      this.CapsuleItemH(0, getString($r('app.string.tab_tunnels')), $r('sys.symbol.wifi'))
      this.CapsuleItemH(1, getString($r('app.string.page_settings')), $r('sys.symbol.list_bullet'))
    }
    .padding(6)
    .backgroundColor($r('app.color.glass_bar'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(28)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
  }

  // 平板/2in1 左侧纵向胶囊 Tab 栏
  @Builder
  TabCapsuleV() {
    Column({ space: 4 }) {
      this.CapsuleItemV(0, getString($r('app.string.tab_tunnels')), $r('sys.symbol.wifi'))
      this.CapsuleItemV(1, getString($r('app.string.page_settings')), $r('sys.symbol.list_bullet'))
    }
    .padding(6)
    .backgroundColor($r('app.color.glass_bar'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(28)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
    .margin({ left: 16 })
  }

  // 打开某隧道详情：手机端一镜到底展开全屏 Cover；平板/2in1 右栏内联。
  private openDetail(id: string): void {
    if (this.breakpoint === Breakpoint.COMPACT) {
      this.detailCoverId = id;
      this.getUIContext().animateTo({ duration: 350, curve: Curve.Friction }, () => {
        this.detailCoverShow = true;
      });
    } else {
      this.selectedConfigId = id;
    }
  }

  private closeDetail(): void {
    this.getUIContext().animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.detailCoverShow = false;
    });
  }

  private openActiveDetail(): void {
    const cfg = this.getActiveConfig();
    if (cfg) {
      this.openDetail(cfg.id);
    }
  }

  // 详情页「编辑」：手机端先收起 Cover（Cover 是覆盖层，不收起会盖住入栈的编辑页），再入编辑页。
  private editConfig(id: string): void {
    const cfg = configManager.getConfigById(id);
    if (!cfg) {
      return;
    }
    if (this.detailCoverShow) {
      this.closeDetail();
    }
    this.pageStack.pushPath({ name: 'ConfigEdit', param: cfg });
  }

  // 详情页「删除」：二次确认后删除；若该配置正在连接/连接中先断开，再收起详情并刷新列表。
  private requestDeleteConfig(id: string): void {
    if (!id) {
      return;
    }
    DialogHelper.showConfirm(this.getUIContext(), {
      title: getString($r('app.string.dialog_delete_config_title')),
      message: getString($r('app.string.dialog_delete_config_message')),
      confirmText: getString($r('app.string.button_delete')),
      secure: true,
      onConfirm: () => {
        if (this.activeConfigId === id) {
          const cfg = configManager.getConfigById(id);
          if (cfg) {
            this.toggleVpn(cfg, false);
          }
        }
        configManager.deleteConfig(id);
        if (this.detailCoverShow) {
          this.closeDetail();
        }
        if (this.selectedConfigId === id) {
          this.selectedConfigId = '';
        }
        this.loadConfigs();
      }
    });
  }

  // 连接中可折叠 MiniBar：折叠=紧凑控制条（状态点+名称+断开）；
  // 展开=完整信息（Endpoint/实时流量/详情）。嵌于底部导航之上，空间高效。
  @Builder
  MiniBar() {
    Column() {
      // 折叠态紧凑控制条（始终显示）
      Row({ space: SPACING.sm }) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.statusColorRes())

        Column() {
          Text(this.getActiveConfig()?.name ?? '')
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusTextLabel())
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          this.openActiveDetail();
        })

        Button(getString($r('app.string.button_disconnect')))
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.danger'))
          .backgroundColor($r('app.color.danger_bg'))
          .height(32)
          .padding({ left: SPACING.md, right: SPACING.md })
          .borderRadius(16)
          .onClick(() => {
            const cfg = this.getActiveConfig();
            if (cfg) {
              this.toggleVpn(cfg, false);
            }
          })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('app.color.text_tertiary')])
          .rotate({ angle: this.miniExpanded ? 90 : -90 })
          .hoverEffect(HoverEffect.Highlight)
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
              this.miniExpanded = !this.miniExpanded;
            });
          })
      }
      .width('100%')
      .height(56)

      // 展开态：完整信息 + 控制
      if (this.miniExpanded) {
        Column({ space: SPACING.xs }) {
          Divider()
            .color($r('app.color.divider'))

          Row() {
            Text(getString($r('app.string.field_endpoint_host')))
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_tertiary'))
            Blank()
            Text(this.getActiveConfig()?.endpoint ?? '')
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')

          Row() {
            Text('↓ ' + formatBytes(this.rxBytes))
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_secondary'))
            Blank()
            Text('↑ ' + formatBytes(this.txBytes))
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')

          Button(getString($r('app.string.button_detail')))
            .width('100%')
            .height(36)
            .fontSize(TYPOGRAPHY.body_sm.size)
            .backgroundColor($r('app.color.surface_subtle'))
            .fontColor($r('app.color.primary'))
            .onClick(() => {
              this.openActiveDetail();
            })
        }
        .width('100%')
        .padding({ top: SPACING.xs, bottom: SPACING.sm })
        // 展开态内容随折叠 animateTo 淡入/下滑，而非生硬弹出
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 })))
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 480 })
    .padding({ left: SPACING.md, right: SPACING.md })
    .backgroundColor($r('app.color.glass_bar'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(24)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
  }

  // 底部导航组合：可折叠 MiniBar（连接中）+ Tab 胶囊，作为一个悬浮单元。
  @Builder
  BottomDock() {
    Column({ space: 10 }) {
      if (this.activeConfigId !== '') {
        this.MiniBar()
      }
      this.TabCapsuleH()
    }
    .alignItems(HorizontalAlign.Center)
    .width('92%')
    .constraintSize({ maxWidth: 480 })
    .margin({ bottom: 24 })
  }

  // 手机端隧道详情 Cover：一镜到底——从列表卡片原地放大展开为全屏，关闭再收回。
  @Builder
  DetailCover() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .hoverEffect(HoverEffect.Highlight)
          .onClick(() => {
            this.closeDetail();
          })

        Text(getString($r('app.string.page_tunnel_detail')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(24)
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      TunnelDetailPanel({
        configId: this.detailCoverId,
        onEdit: () => {
          this.editConfig(this.detailCoverId);
        },
        onDelete: () => {
          this.requestDeleteConfig(this.detailCoverId);
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .geometryTransition('detail_' + this.detailCoverId)
  }

  build() {
    Navigation(this.pageStack) {
      Stack({ alignContent: this.breakpoint === Breakpoint.COMPACT ? Alignment.Bottom : Alignment.Start }) {
        // 主体内容（按当前 Tab 切换）。Tab 切换用交叉淡入 + 轻微上移的转场，
        // 由胶囊点击里的 animateTo 驱动 .transition()，不再生硬闪切。
        if (this.breakpoint === Breakpoint.COMPACT) {
          if (this.currentTabIndex === 0) {
            Column() {
              this.CompactLayout()
            }
            .width('100%')
            .height('100%')
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 })))
          } else {
            Column() {
              SettingsPage({ embedded: true })
            }
            .width('100%')
            .height('100%')
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 })))
          }
        } else {
          // 平板/2in1：左侧留位给悬浮胶囊
          Column() {
            if (this.currentTabIndex === 0) {
              Column() {
                this.SplitLayout(this.masterWidth())
              }
              .width('100%')
              .height('100%')
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 })))
            } else {
              Column() {
                SettingsPage({ embedded: true })
              }
              .width('100%')
              .height('100%')
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 })))
            }
          }
          .width('100%')
          .height('100%')
          .padding({ left: 104 })
        }

        // 底部导航：手机端 = MiniBar + Tab 胶囊组合悬浮单元（居中底部）
        if (this.breakpoint === Breakpoint.COMPACT) {
          this.BottomDock()
        } else {
          // 平板/2in1：左侧纵向胶囊 Tab 栏
          this.TabCapsuleV()
          // 连接中 MiniBar 浮于内容区底部居中
          if (this.activeConfigId !== '') {
            Column() {
              this.MiniBar()
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Center)
            .padding({ left: 120, right: 16, bottom: 24 })
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background'))
      .onAreaChange((_oldArea, newArea) => {
        if (newArea.width > 0) {
          this.windowWidth = this.getUIContext().px2vp(newArea.width as number);
          this.breakpoint = getBreakpoint(this.windowWidth);
        }
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(PageMap)
    // 一镜到底：手机端隧道详情走全屏 Cover（不经 NavPathStack，不会卡返回），
    // 由 openDetail/closeDetail 的 animateTo 驱动 geometryTransition 形变。
    .bindContentCover($$this.detailCoverShow, this.DetailCover(), { modalTransition: ModalTransition.NONE })
  }
}
