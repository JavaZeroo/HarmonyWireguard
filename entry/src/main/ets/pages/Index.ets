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
import { APP_CONSTANTS } from '../common/Constants';
import { SPACING, RADIUS, TYPOGRAPHY, Breakpoint, getBreakpoint, getString } from '../common/DesignSystem';
import { formatBytes } from '../common/Formatters';
import { shouldApplyToggle, ToggleContext } from '../common/Utils';
import { ConnectionHeroCard } from '../components/tunnel/ConnectionHeroCard';
import { TunnelListItem } from '../components/tunnel/TunnelListItem';
import { EmptyState } from '../components/common/EmptyState';
import { tunnelRuntimeService } from '../service/TunnelRuntimeService';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';
import { ImportActions } from '../service/ImportActions';
import { DialogHelper } from '../common/DialogHelper';
import { PageHeader } from '../components/app/PageHeader';
import { AdaptiveTabBar } from '../components/app/AdaptiveTabBar';
import { PasteConfigPage } from './PasteConfigPage';
import { settingsService } from '../service/SettingsService';
import { decodeWgStatusPayload } from '../common/WgStatusCodec';

const TAG = 'IndexPage';
const ACTIVE_RESTORE_TIMEOUT_MS = 15000;

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
  // NavPathStack 是可变导航控制器，不应被声明为 ArkUI 响应式状态。
  // API 26 会在 Navigation 初始化栈时检测到 @Provide 变更，并报 build 期间修改状态。
  private readonly pageStack: NavPathStack = new NavPathStack();
  @State configs: WgConfig[] = [];
  @State activeConfigId: string = '';
  @State activeStatus: TunnelStatusType = 'disconnected';
  @State connectingId: string = '';
  @State rxBytes: number = 0;
  @State txBytes: number = 0;
  @State lastHandshakeAt: number = -1;
  @State selectedConfigId: string = '';
  @State windowWidth: number = 360;
  @State currentTabIndex: number = 0;
  @State miniExpanded: boolean = false;
  @State compactMode: boolean = false;
  // 手机端隧道详情：改用 bindContentCover 全屏展开（一镜到底），不走 Navigation push
  @State detailCoverShow: boolean = false;
  @State detailCoverId: string = '';
  // FAB 添加菜单是否展开：驱动 “+” 旋转成 “×”
  @State fabMenuOpen: boolean = false;

  private unsubscribe?: () => void;
  private statusSubscriber: commonEventManager.CommonEventSubscriber | null = null;
  private isStatusSubscriberPending: boolean = false;
  private isPageActive: boolean = false;
  private lastConnLogged: number = -1;
  private restoreValidationTimer: number = -1;

  aboutToAppear(): void {
    this.isPageActive = true;
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    configManager.init(ctx);
    settingsService.init(ctx);
    this.compactMode = settingsService.getBool('compactMode');
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
    this.isPageActive = false;
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.teardownStatusSubscriber();
    this.cancelRestoreValidation();
  }

  // 订阅扩展子进程回传的实时状态/流量事件，喂给 TunnelRuntimeService
  private setupStatusSubscriber(): void {
    if (this.statusSubscriber || this.isStatusSubscriberPending) {
      return;
    }
    this.isStatusSubscriberPending = true;
    const info: commonEventManager.CommonEventSubscribeInfo = {
      events: [APP_CONSTANTS.VPN_STATUS_EVENT],
      publisherBundleName: APP_CONSTANTS.BUNDLE_NAME
    };
    commonEventManager.createSubscriber(info,
      (err: BusinessError, subscriber: commonEventManager.CommonEventSubscriber) => {
        this.isStatusSubscriberPending = false;
        if (err) {
          hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'createSubscriber failed: %{public}d', err.code);
          return;
        }
        // createSubscriber 是异步的；页面销毁后迟到的回调不能再注册事件。
        if (!this.isPageActive) {
          return;
        }
        this.statusSubscriber = subscriber;
        commonEventManager.subscribe(subscriber,
          (subErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (subErr || !this.isPageActive) {
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
    const payload: WgStatusPayload | null = decodeWgStatusPayload(body);
    if (payload === null) {
      hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'Ignored invalid VPN status payload');
      return;
    }
    if (this.activeConfigId === configId) {
      this.cancelRestoreValidation();
    }
    const isActiveEvent = payload.state !== 'disconnected';
    if (!this.activeConfigId && isActiveEvent) {
      const config = this.configs.find(item => item.id === configId);
      if (config) {
        this.activeConfigId = configId;
        if (payload.state !== 'failed') {
          configManager.setActiveConfigId(configId);
        }
      }
    }

    if (payload.state === 'disconnected') {
      configManager.clearActiveConfigId(configId);
      if (this.activeConfigId === configId || this.connectingId === configId) {
        this.clearActiveUiState();
      }
    } else if (payload.state === 'failed') {
      // 扩展启动流程失败同样不能留下可被下次启动误恢复的配置 id。
      configManager.clearActiveConfigId(configId);
      if (this.connectingId === configId) {
        this.connectingId = '';
      }
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
  }

  loadConfigs(): void {
    this.configs = configManager.getAllConfigs();
    this.restoreActiveConfig();
  }

  private restoreActiveConfig(): void {
    const persistedId = configManager.getActiveConfigId();
    if (!persistedId) {
      if (this.activeConfigId) {
        this.clearActiveUiState();
      }
      return;
    }

    const config = this.configs.find(item => item.id === persistedId);
    if (!config) {
      configManager.clearActiveConfigId(persistedId);
      tunnelRuntimeService.resetState(persistedId);
      this.clearActiveUiState();
      return;
    }

    this.activeConfigId = persistedId;
    const state = tunnelRuntimeService.getState(persistedId);
    this.activeStatus = state?.status ?? 'connecting';
    this.rxBytes = state?.rxBytes ?? 0;
    this.txBytes = state?.txBytes ?? 0;
    this.lastHandshakeAt = state?.lastHandshakeAt ?? -1;
    this.scheduleRestoreValidation(persistedId);
  }

  private scheduleRestoreValidation(configId: string): void {
    this.cancelRestoreValidation();
    this.restoreValidationTimer = setTimeout(() => {
      this.restoreValidationTimer = -1;
      if (!this.isPageActive || this.activeConfigId !== configId) {
        return;
      }
      const state = tunnelRuntimeService.getState(configId);
      const hasRecentHeartbeat = state !== undefined &&
        Date.now() - state.updatedAt <= ACTIVE_RESTORE_TIMEOUT_MS;
      if (!hasRecentHeartbeat) {
        configManager.clearActiveConfigId(configId);
        tunnelRuntimeService.resetState(configId);
        this.clearActiveUiState();
      }
    }, ACTIVE_RESTORE_TIMEOUT_MS);
  }

  private cancelRestoreValidation(): void {
    if (this.restoreValidationTimer !== -1) {
      clearTimeout(this.restoreValidationTimer);
      this.restoreValidationTimer = -1;
    }
  }

  private clearActiveUiState(): void {
    this.cancelRestoreValidation();
    this.activeConfigId = '';
    this.connectingId = '';
    this.activeStatus = 'disconnected';
    this.rxBytes = 0;
    this.txBytes = 0;
    this.lastHandshakeAt = -1;
    this.miniExpanded = false;
  }

  getActiveConfig(): WgConfig | undefined {
    if (!this.activeConfigId) return undefined;
    return this.configs.find(c => c.id === this.activeConfigId);
  }

  async toggleVpn(config: WgConfig, enable: boolean): Promise<boolean> {
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
    if (enable && this.activeConfigId !== '' && this.activeConfigId !== config.id &&
      (this.activeStatus === 'connected' || this.activeStatus === 'connecting')) {
      this.showToast(getString($r('app.string.error_disconnect_before_switch')));
      // Toggle has its own pressed animation. Rebind the list immediately so
      // a rejected switch cannot remain visually enabled.
      this.configs = this.configs.slice();
      return false;
    }
    if (!shouldApplyToggle(config.id, enable, toggleCtx)) {
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'toggleVpn ignored (guard): enable=%{public}s', String(enable));
      return false;
    }
    if (enable) {
      this.connectingId = config.id;
      this.activeConfigId = config.id;
      this.activeStatus = 'connecting';
      let started = false;
      try {
        // 系统 VPN 授权对话框会丢掉 want.parameters，所以把要用的配置 id 写到 prefs
        if (!configManager.setActiveConfigId(config.id)) {
          throw new Error('Failed to persist active config');
        }
        tunnelRuntimeService.setStatus(config.id, 'connecting');
        const want = createWant(config);
        hilog.info(APP_CONSTANTS.DOMAIN, TAG,
          'startVpnExtensionAbility: bundle=%{public}s module=%{public}s ability=%{public}s configId=%{public}s',
          want.bundleName ?? '', want.moduleName ?? '', want.abilityName ?? '', config.id);
        await vpnExtension.startVpnExtensionAbility(want);
        // The UI already entered connecting before the await. Do not assign it
        // again here: a fast failure event may have arrived while awaiting.
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN extension started for %{public}s', config.name);
        started = true;
        this.scheduleRestoreValidation(config.id);
      } catch (err) {
        const e = err as BusinessError;
        const code = e?.code !== undefined ? String(e.code) : '?';
        const msg = e?.message ?? String(err);
        this.activeStatus = 'failed';
        tunnelRuntimeService.setStatus(config.id, 'failed', msg);
        configManager.clearActiveConfigId(config.id);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG,
          'Failed to start VPN: code=%{public}s msg=%{public}s', code, msg);
      }
      this.connectingId = '';
      return started;
    } else {
      try {
        await vpnExtension.stopVpnExtensionAbility(createStopWant());
        this.activeStatus = 'disconnected';
        tunnelRuntimeService.setStatus(config.id, 'disconnected');
        configManager.clearActiveConfigId(config.id);
        if (this.activeConfigId === config.id) {
          this.clearActiveUiState();
        }
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN stopped');
        return true;
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to stop VPN: %{public}s', msg);
        this.showToast(getString($r('app.string.error_stop_vpn')));
        return false;
      }
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch {}
  }

  // 成员 Builder 可安全捕获非响应式 pageStack，并显式传给目的页。
  @Builder
  PageMap(name: string, param: Object) {
    if (name === 'About') {
      NavDestination() { AboutPage({ pageStack: this.pageStack }) }.hideTitleBar(true)
    } else if (name === 'ConfigEdit') {
      NavDestination() {
        ConfigEditPage({ navParam: param, pageStack: this.pageStack })
      }.hideTitleBar(true)
    } else if (name === 'ConfigPreview') {
      NavDestination() {
        ConfigPreviewPage({ navParam: param, pageStack: this.pageStack })
      }.hideTitleBar(true)
    } else if (name === 'PasteConfig') {
      NavDestination() { PasteConfigPage({ pageStack: this.pageStack }) }.hideTitleBar(true)
    }
  }

  @Builder
  EmptyActionBuilder() {
    Column({ space: SPACING.sm }) {
      if (ImportActions.isQrScanSupported()) {
        Button(getString($r('app.string.button_scan_qr')))
          .width('72%')
          .constraintSize({ maxWidth: 320 })
          .height(48)
          .onClick(() => {
            ImportActions.scanQR(this.getUIContext(), this.pageStack);
          })
      }

      Button(getString($r('app.string.button_import_file')))
        .width('72%')
        .constraintSize({ maxWidth: 320 })
        .height(48)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          ImportActions.fromFile(this.getUIContext(), this.pageStack);
        })

      Button(getString($r('app.string.button_import_clipboard')))
        .width('72%')
        .constraintSize({ maxWidth: 320 })
        .height(48)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          ImportActions.pasteConfig(this.pageStack);
        })

      Button(getString($r('app.string.button_create_manual')))
        .width('72%')
        .constraintSize({ maxWidth: 320 })
        .height(48)
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
    const items: MenuElement[] = [];
    if (ImportActions.isQrScanSupported()) {
      items.push({
        value: getString($r('app.string.button_scan_qr')),
        action: () => { ImportActions.scanQR(ctx, stack); }
      });
    }
    items.push(
      {
        value: getString($r('app.string.button_import_file')),
        action: () => { ImportActions.fromFile(ctx, stack); }
      },
      {
        value: getString($r('app.string.button_import_clipboard')),
        action: () => { ImportActions.pasteConfig(stack); }
      },
      {
        value: getString($r('app.string.button_create_manual')),
        action: () => { ImportActions.manualCreate(stack); }
      }
    );
    return items;
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
    return this.isCompactUX() ? 44 : SPACING.xs;
  }

  // 底部留白避开悬浮 Dock（Tab 胶囊 / 连接中 MiniBar，展开时更高）。
  private bottomContentClearance(): number {
    if (!this.isCompactUX()) {
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
      latestError: tunnelRuntimeService.getState(this.activeConfigId)?.latestError ?? '',
      onPrimaryAction: () => {
        if (this.activeStatus === 'connected' || this.activeStatus === 'connecting') {
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
  ConfigListContent(containerWidth: number) {
    if (this.configs.length === 0) {
      Scroll() {
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
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .padding({ left: SPACING.lg, right: SPACING.lg, top: 52, bottom: 112 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      List({ space: this.compactMode ? SPACING.sm : SPACING.md }) {
        ListItem() {
          Row().width('100%').height(this.topContentClearance())
        }

        if (this.activeConfigId && this.isCompactUX()) {
          ListItem() {
            this.HeroListItem()
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
                name: config.name,
                endpoint: config.endpoint,
                allowedIPs: config.allowedIPs,
                persistentKeepalive: config.persistentKeepalive,
                status: config.id === this.activeConfigId ? this.activeStatus : 'disconnected',
                selected: !this.isCompactUX() && config.id === this.expandedDetailId(),
                compact: this.compactMode,
                sharedTag: this.isCompactUX() ? ('detail_' + config.id) : '',
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
      .padding({ left: this.listSidePadding(containerWidth), right: this.listSidePadding(containerWidth) })
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
  ExpandedAddButton() {
    Button() {
      Text('+')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .rotate({ angle: this.fabMenuOpen ? 45 : 0 })
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })
    }
    .width(44)
    .height(44)
    .backgroundColor($r('app.color.primary'))
    .borderRadius(RADIUS.full)
    .shadow({ radius: 6, color: 'rgba(0,125,255,0.22)', offsetY: 3 })
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityText($r('app.string.accessibility_add_config'))
    .bindMenu(this.importMenuItems(), {
      onAppear: () => {
        this.fabMenuOpen = true;
      },
      onDisappear: () => {
        this.fabMenuOpen = false;
      }
    })
  }

  // 横屏标题收进内容画布，不再用贯穿整窗的玻璃长条。
  @Builder
  ExpandedHeader() {
    Row({ space: SPACING.md }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.wifi'))
          .fontSize(24)
          .fontColor([$r('app.color.primary')])
      }
      .width(44)
      .height(44)
      .backgroundColor($r('app.color.primary_bg'))
      .borderRadius(RADIUS.md)

      Column({ space: SPACING.xxs }) {
        Text(getString($r('app.string.page_home')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Row({ space: SPACING.xs }) {
          Text(getString($r('app.string.section_configs')))
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_secondary'))
          Text(this.configs.length.toString())
            .fontSize(TYPOGRAPHY.caption.size)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (this.activeConfigId !== '') {
        Row({ space: SPACING.xs }) {
          Circle()
            .width(8)
            .height(8)
            .fill(this.statusColorRes())
          Text(this.statusTextLabel())
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColorRes())
        }
        .padding({ left: SPACING.sm, right: SPACING.sm, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.full)
      }

      this.ExpandedAddButton()
    }
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: SPACING.md, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.xl)
    .shadow({ radius: 6, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
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
    .accessibilityText($r('app.string.accessibility_add_config'))
    // 上抬避开底部悬浮 Dock（Tab 胶囊 / 连接中 MiniBar，展开时更高）
    .margin({
      right: SPACING.md,
      bottom: this.isCompactUX()
        ? (this.activeConfigId !== '' ? (this.miniExpanded ? 264 : 160) : 72)
        : SPACING.lg
    })
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
      this.ConfigListContent(this.windowWidth)

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

  // 单栏 UX：< 960vp 一律单栏 + 全屏详情 Cover；≥960vp 才启用侧栏与主从分栏。
  // 这样手机横屏 / 平板竖屏不会被 104vp 导航栏与 360vp 主栏挤压详情内容。
  private isCompactUX(): boolean {
    return getBreakpoint(this.windowWidth) !== Breakpoint.EXPANDED;
  }

  // 分栏主栏宽度（仅 lg 调用）：超大屏（≥1440vp）更宽（占比思想）。
  private masterWidth(): number {
    if (this.windowWidth >= 1600) {
      return 384;
    }
    if (this.windowWidth >= 1200) {
      return 352;
    }
    return 328;
  }

  // 单栏内容限宽居中（缩进布局）：容器够宽时用左右内边距把列表夹到 ~640 居中，
  // 避免 md(600–960) 单栏时卡片被拉得过宽；窄容器（如分栏主栏 360）退回常规页边距。
  private listSidePadding(containerWidth: number): number {
    const maxContent = 520;
    if (containerWidth > maxContent + 2 * SPACING.lg) {
      return (containerWidth - maxContent) / 2;
    }
    return this.compactMode ? SPACING.sm : SPACING.md;
  }

  private expandedDetailId(): string {
    if (this.selectedConfigId !== '') {
      return this.selectedConfigId;
    }
    if (this.activeConfigId !== '') {
      return this.activeConfigId;
    }
    return this.configs.length > 0 ? this.configs[0].id : '';
  }

  // 平板 / 折叠屏 / 2in1：有限宽画布内采用隧道栏 + 详情面板，避免横向拉成通栏。
  @Builder
  SplitLayout(masterWidth: number) {
    Column() {
      Column({ space: SPACING.md }) {
        this.ExpandedHeader()

        Row({ space: SPACING.md }) {
          Stack() {
            this.ConfigListContent(masterWidth)
          }
          .width(masterWidth)
          .height('100%')
          .backgroundColor($r('app.color.surface_subtle'))
          .borderRadius(RADIUS.xl)
          .clip(true)

          Stack() {
            if (this.expandedDetailId() !== '') {
              TunnelDetailPanel({
                configId: this.expandedDetailId(),
                contentMaxWidth: 720,
                compact: this.compactMode,
                onEdit: () => {
                  this.editConfig(this.expandedDetailId());
                },
                onDelete: () => {
                  this.requestDeleteConfig(this.expandedDetailId());
                }
              })
                .width('100%')
                .height('100%')
            } else {
              this.DetailPlaceholder()
            }
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius(RADIUS.xl)
          .clip(true)
          .shadow({ radius: 6, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: 1240 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: SPACING.lg, right: SPACING.lg, top: SPACING.md, bottom: SPACING.lg })
  }

  // 打开某隧道详情：手机端一镜到底展开全屏 Cover；平板/2in1 右栏内联。
  private openDetail(id: string): void {
    if (this.isCompactUX()) {
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

  private async deleteConfigAfterStop(id: string): Promise<void> {
    if (this.activeConfigId === id &&
      (this.activeStatus === 'connected' || this.activeStatus === 'connecting')) {
      const cfg = configManager.getConfigById(id);
      if (!cfg || !(await this.toggleVpn(cfg, false))) {
        return;
      }
    } else if (this.activeConfigId === id) {
      configManager.clearActiveConfigId(id);
      this.clearActiveUiState();
    }

    if (!configManager.deleteConfig(id)) {
      this.showToast(getString($r('app.string.error_delete_config')));
      return;
    }
    if (this.detailCoverShow) {
      this.closeDetail();
    }
    if (this.selectedConfigId === id) {
      this.selectedConfigId = '';
    }
    this.loadConfigs();
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
        this.deleteConfigAfterStop(id);
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
        .constraintSize({ minHeight: 48 })
        .justifyContent(FlexAlign.Center)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(getString($r('app.string.accessibility_view_tunnel'))
          .replace('%s', this.getActiveConfig()?.name ?? ''))
        .onClick(() => {
          this.openActiveDetail();
        })

        Button(getString($r('app.string.button_disconnect')))
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.danger'))
          .backgroundColor($r('app.color.danger_bg'))
          .height(48)
          .padding({ left: SPACING.md, right: SPACING.md })
          .borderRadius(16)
          .onClick(() => {
            const cfg = this.getActiveConfig();
            if (cfg) {
              this.toggleVpn(cfg, false);
            }
          })

        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('app.color.text_tertiary')])
            .rotate({ angle: this.miniExpanded ? 90 : -90 })
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .hoverEffect(HoverEffect.Highlight)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(this.miniExpanded
          ? $r('app.string.accessibility_collapse_connection')
          : $r('app.string.accessibility_expand_connection'))
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
            .height(48)
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
      AdaptiveTabBar({
        currentIndex: this.currentTabIndex,
        onChange: (index: number) => {
          this.currentTabIndex = index;
        }
      })
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
      PageHeader({
        title: getString($r('app.string.page_tunnel_detail')),
        onBack: () => {
          this.closeDetail();
        }
      })

      TunnelDetailPanel({
        configId: this.detailCoverId,
        compact: this.compactMode,
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
      Stack({ alignContent: this.isCompactUX() ? Alignment.Bottom : Alignment.Start }) {
        // 主体内容（按当前 Tab 切换）。Tab 切换用交叉淡入 + 轻微上移的转场，
        // 由胶囊点击里的 animateTo 驱动 .transition()，不再生硬闪切。
        if (this.isCompactUX()) {
          if (this.currentTabIndex === 0) {
            Column() {
              this.CompactLayout()
            }
            .width('100%')
            .height('100%')
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 })))
          } else {
            Column() {
              SettingsPage({
                pageStack: this.pageStack,
                embedded: true,
                bottomInset: this.bottomContentClearance(),
                onCompactModeChange: (isCompact: boolean) => {
                  this.compactMode = isCompact;
                }
              })
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
                SettingsPage({
                  pageStack: this.pageStack,
                  embedded: true,
                  bottomInset: this.bottomContentClearance(),
                  onCompactModeChange: (isCompact: boolean) => {
                    this.compactMode = isCompact;
                  }
                })
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

        // 底部导航：单栏 UX = MiniBar + Tab 胶囊组合悬浮单元（居中底部）
        if (this.isCompactUX()) {
          this.BottomDock()
        } else {
          // 平板/2in1：左侧纵向胶囊 Tab 栏
          AdaptiveTabBar({
            currentIndex: this.currentTabIndex,
            vertical: true,
            onChange: (index: number) => {
              this.currentTabIndex = index;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background'))
      .onAreaChange((_oldArea, newArea) => {
        if (newArea.width > 0) {
          // Area.width 已是 vp；再次 px2vp 会把横屏宽度缩小一遍并误判成手机布局。
          const nextWidth = newArea.width as number;
          if (Math.abs(nextWidth - this.windowWidth) >= 1) {
            this.windowWidth = nextWidth;
          }
        }
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.PageMap)
    // 一镜到底：手机端隧道详情走全屏 Cover（不经 NavPathStack，不会卡返回），
    // 由 openDetail/closeDetail 的 animateTo 驱动 geometryTransition 形变。
    .bindContentCover($$this.detailCoverShow, this.DetailCover(), { modalTransition: ModalTransition.NONE })
  }
}
