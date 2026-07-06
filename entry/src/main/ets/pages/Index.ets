import { vpnExtension } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { configManager } from '../service/ConfigManager';
import type { WgConfig, TunnelStatusType, WgStatusPayload } from '../model/WgConfig';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';
import { ImportConfigPage } from './ImportConfigPage';
import { ConfigEditPage } from './ConfigEditPage';
import { ConfigPreviewPage } from './ConfigPreviewPage';
import { TunnelDetailPage } from './TunnelDetailPage';
import { APP_CONSTANTS } from '../common/Constants';
import { SPACING, TYPOGRAPHY, Breakpoint, getBreakpoint, getString } from '../common/DesignSystem';
import { ConnectionHeroCard } from '../components/tunnel/ConnectionHeroCard';
import { TunnelListItem } from '../components/tunnel/TunnelListItem';
import { EmptyState } from '../components/common/EmptyState';
import { DiagnosticSummaryCard } from '../components/tunnel/DiagnosticSummaryCard';
import type { DiagnosticItem } from '../model/WgConfig';
import { tunnelRuntimeService } from '../service/TunnelRuntimeService';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';

const TAG = 'IndexPage';

// Navigation 目的地路由表（顶层 @Builder，navDestination 要求函数引用，不能内联 lambda）
@Builder
function PageMap(name: string, param: Object) {
  if (name === 'Settings') {
    NavDestination() { SettingsPage() }.hideTitleBar(true)
  } else if (name === 'About') {
    NavDestination() { AboutPage() }.hideTitleBar(true)
  } else if (name === 'Import') {
    NavDestination() { ImportConfigPage() }.hideTitleBar(true)
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
          this.pageStack.pushPath({ name: 'Import' });
        })

      Button(getString($r('app.string.button_import_file')))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          this.pageStack.pushPath({ name: 'Import' });
        })

      Button(getString($r('app.string.button_create_manual')))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          this.pageStack.pushPath({ name: 'ConfigEdit' });
        })
    }
    .width('100%')
  }

  @Builder
  ConfigListContent() {
    Column() {
      if (this.configs.length === 0) {
        EmptyState({
          icon: 'wifi_slash',
          title: getString($r('app.string.empty_config_title')),
          description: getString($r('app.string.empty_config_desc'))
        }) {
          this.EmptyActionBuilder()
        }
      } else {
        if (this.activeConfigId) {
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
              const cfg = this.getActiveConfig();
              if (!cfg) return;
              if (this.breakpoint === Breakpoint.COMPACT) {
                this.pageStack.pushPath({ name: 'TunnelDetail', param: cfg.id });
              } else {
                this.selectedConfigId = cfg.id;
              }
            }
          })
          .margin({ left: SPACING.md, right: SPACING.md, top: SPACING.md })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
            .combine(TransitionEffect.translate({ y: -10 }))
            .animation({ duration: 350, curve: Curve.FastOutSlowIn }))
        }

        if (this.diagnostics.length > 0) {
          DiagnosticSummaryCard({ items: this.diagnostics })
            .margin({ left: SPACING.md, right: SPACING.md, top: SPACING.md })
        }

        Text(getString($r('app.string.section_configs')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({ top: SPACING.lg, bottom: SPACING.sm, left: SPACING.md, right: SPACING.md })

        Column({ space: SPACING.sm }) {
          ForEach(this.configs, (config: WgConfig) => {
            TunnelListItem({
              config: config,
              status: config.id === this.activeConfigId ? this.activeStatus : 'disconnected',
              selected: config.id === this.selectedConfigId || config.id === this.activeConfigId,
              onSelect: () => {
                if (this.breakpoint === Breakpoint.COMPACT) {
                  this.pageStack.pushPath({ name: 'TunnelDetail', param: config.id });
                } else {
                  this.selectedConfigId = config.id;
                }
              },
              onConnect: () => {
                this.toggleVpn(config, true);
              },
              onDisconnect: () => {
                this.toggleVpn(config, false);
              }
            })
            .margin({ left: SPACING.md, right: SPACING.md })
          }, (config: WgConfig) => config.id)
        }
        .width('100%')
        .padding({ bottom: 96 })
      }
    }
    .width('100%')
  }

  @Builder
  CompactLayout() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Header
        Row() {
          Text(getString($r('app.string.page_home')))
            .fontSize(TYPOGRAPHY.title_lg.size)
            .fontWeight(TYPOGRAPHY.title_lg.weight)
            .fontColor($r('app.color.text_primary'))

          Blank()

          SymbolGlyph($r('sys.symbol.list_bullet'))
            .fontSize(24)
            .fontColor([$r('app.color.text_secondary')])
            .onClick(() => {
              this.pageStack.pushPath({ name: 'Settings' });
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: SPACING.md, right: SPACING.md })
        .backgroundColor($r('app.color.surface'))

        Scroll() {
          this.ConfigListContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background'))

      // FAB only shown when there are configs
      if (this.configs.length > 0) {
        Button() {
          Text('+')
            .fontSize(24)
            .fontColor('#FFFFFF')
        }
        .width(56)
        .height(56)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(28)
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.20)', offsetY: 4 })
        .margin({ right: SPACING.md, bottom: SPACING.lg })
        .hoverEffect(HoverEffect.Scale)
        .onClick(() => {
          this.pageStack.pushPath({ name: 'Import' });
        })
      }
    }
    .width('100%')
    .height('100%')
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

  @Builder
  SidebarNavigation() {
    Column() {
      Text(getString($r('app.string.app_name')))
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: SPACING.lg })

      List({ space: SPACING.sm }) {
        ForEach(this.configs, (config: WgConfig) => {
          ListItem() {
            Row() {
              SymbolGlyph($r('sys.symbol.wifi'))
                .fontSize(20)
                .fontColor([config.id === this.activeConfigId ? $r('app.color.primary') : $r('app.color.text_secondary')])
                .margin({ right: SPACING.sm })

              Text(config.name)
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor(config.id === this.activeConfigId ? $r('app.color.primary') : $r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(44)
            .padding({ left: SPACING.sm, right: SPACING.sm })
            .backgroundColor(config.id === this.selectedConfigId ? $r('app.color.primary_bg') : 'transparent')
            .borderRadius(8)
            .onClick(() => {
              this.selectedConfigId = config.id;
            })
          }
        }, (config: WgConfig) => config.id)
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        SymbolGlyph($r('sys.symbol.list_bullet'))
          .fontSize(20)
          .fontColor([$r('app.color.text_secondary')])
          .margin({ right: SPACING.sm })

        Text(getString($r('app.string.page_settings')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(44)
      .padding({ left: SPACING.sm, right: SPACING.sm })
      .onClick(() => {
        this.pageStack.pushPath({ name: 'Settings' });
      })
    }
    .width('100%')
    .height('100%')
    .padding(SPACING.md)
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  MediumLayout() {
    Row() {
      Column() {
        // Header
        Row() {
          Text(getString($r('app.string.page_home')))
            .fontSize(TYPOGRAPHY.title_lg.size)
            .fontWeight(TYPOGRAPHY.title_lg.weight)
            .fontColor($r('app.color.text_primary'))

          Blank()

          SymbolGlyph($r('sys.symbol.list_bullet'))
            .fontSize(24)
            .fontColor([$r('app.color.text_secondary')])
            .onClick(() => {
              this.pageStack.pushPath({ name: 'Settings' });
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: SPACING.md, right: SPACING.md })
        .backgroundColor($r('app.color.surface'))

        Scroll() {
          this.ConfigListContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
      }
      .width(320)
      .height('100%')
      .backgroundColor($r('app.color.background'))

      Divider()
        .vertical(true)
        .strokeWidth(1)
        .color($r('app.color.divider'))

      if (this.selectedConfigId) {
        TunnelDetailPanel({ configId: this.selectedConfigId })
          .layoutWeight(1)
      } else {
        Stack() {
          this.DetailPlaceholder()
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ExpandedLayout() {
    Row() {
      Stack() {
        this.SidebarNavigation()
      }
      .width(240)
      .height('100%')

      Divider()
        .vertical(true)
        .strokeWidth(1)
        .color($r('app.color.divider'))

      Column() {
        Scroll() {
          this.ConfigListContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
      }
      .width(320)
      .height('100%')
      .backgroundColor($r('app.color.background'))

      Divider()
        .vertical(true)
        .strokeWidth(1)
        .color($r('app.color.divider'))

      if (this.selectedConfigId) {
        TunnelDetailPanel({ configId: this.selectedConfigId })
          .layoutWeight(1)
      } else {
        Stack() {
          this.DetailPlaceholder()
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Navigation(this.pageStack) {
      Stack() {
        if (this.breakpoint === Breakpoint.COMPACT) {
          this.CompactLayout()
        } else if (this.breakpoint === Breakpoint.MEDIUM) {
          this.MediumLayout()
        } else {
          this.ExpandedLayout()
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
  }
}
