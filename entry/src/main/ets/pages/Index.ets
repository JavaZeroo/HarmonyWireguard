import { vpnExtension } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { configManager } from '../service/ConfigManager';
import type { WgConfig, TunnelStatusType } from '../model/WgConfig';
import { APP_CONSTANTS } from '../common/Constants';
import { SPACING, TYPOGRAPHY, Breakpoint, getBreakpoint } from '../common/DesignSystem';
import { ConnectionHeroCard } from '../components/tunnel/ConnectionHeroCard';
import { TunnelListItem } from '../components/tunnel/TunnelListItem';
import { EmptyState } from '../components/common/EmptyState';
import { DiagnosticSummaryCard } from '../components/tunnel/DiagnosticSummaryCard';
import type { DiagnosticItem } from '../model/WgConfig';
import { tunnelRuntimeService } from '../service/TunnelRuntimeService';

const TAG = 'IndexPage';

interface IpAddress {
  address: string;
  family: number;
}

interface VpnParamAddress {
  address: IpAddress;
  prefixLength: number;
}

interface VpnParamConfig {
  addresses: VpnParamAddress[];
  dnsAddresses: string[];
  mtu: number;
  serverIp: string;
  serverPort: number;
  wgPrivateKey: string;
  wgPeerPublicKey: string;
  wgPresharedKey: string;
  wgKeepalive: number;
}

interface EndpointInfo {
  serverIp: string;
  serverPort: number;
}

function parseAddress(address: string): VpnParamAddress {
  const parts = address.split('/');
  const ip = parts[0];
  const prefix = parts[1];
  return {
    address: { address: ip, family: 1 },
    prefixLength: parseInt(prefix || '24')
  };
}

function parseEndpoint(endpoint: string): EndpointInfo {
  if (endpoint.startsWith('[')) {
    const closingBracket = endpoint.indexOf(']');
    if (closingBracket > 0) {
      const ip = endpoint.substring(1, closingBracket);
      const portPart = endpoint.substring(closingBracket + 1);
      const port = portPart.startsWith(':') ? parseInt(portPart.substring(1)) : 51820;
      return { serverIp: ip, serverPort: port };
    }
  }
  const parts = endpoint.split(':');
  const ip = parts[0];
  const port = parts[1];
  return {
    serverIp: ip,
    serverPort: parseInt(port || '51820')
  };
}

function buildVpnParamConfig(config: WgConfig): VpnParamConfig {
  const ep = parseEndpoint(config.endpoint);
  return {
    addresses: [parseAddress(config.address)],
    dnsAddresses: config.dns ? config.dns.split(',').map(s => s.trim()).filter(s => s.length > 0) : ['8.8.8.8'],
    mtu: config.mtu || 1420,
    serverIp: ep.serverIp,
    serverPort: ep.serverPort,
    wgPrivateKey: config.privateKey,
    wgPeerPublicKey: config.peerPublicKey,
    wgPresharedKey: config.presharedKey,
    wgKeepalive: config.persistentKeepalive || 25
  };
}

function createWant(config: WgConfig): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME,
    parameters: { config: JSON.stringify(buildVpnParamConfig(config)) }
  };
}

function createStopWant(): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME
  };
}

@Entry
@Component
struct Index {
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

  private context = getContext(this) as common.UIAbilityContext;
  private unsubscribe?: () => void;

  aboutToAppear(): void {
    configManager.init(this.context);
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
  }

  aboutToDisappear(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
    }
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
    if (enable) {
      this.connectingId = config.id;
      this.activeStatus = 'connecting';
      try {
        const want = createWant(config);
        await vpnExtension.startVpnExtensionAbility(want);
        this.activeConfigId = config.id;
        this.activeStatus = 'connected';
        tunnelRuntimeService.setStatus(config.id, 'connected');
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN started for %{public}s', config.name);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        this.activeStatus = 'failed';
        tunnelRuntimeService.setStatus(config.id, 'failed', msg);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to start VPN: %{public}s', msg);
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
      Button(getContext().resourceManager.getStringSync($r('app.string.button_scan_qr').id))
        .width('60%')
        .height(44)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ImportConfigPage' });
        })

      Button(getContext().resourceManager.getStringSync($r('app.string.button_import_file').id))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/ImportConfigPage' });
        })

      Button(getContext().resourceManager.getStringSync($r('app.string.button_create_manual').id))
        .width('60%')
        .height(44)
        .backgroundColor($r('app.color.surface_subtle'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/ConfigEditPage' });
        })
    }
    .width('100%')
  }

  @Builder
  ConfigListColumn() {
    Column() {
      Row() {
        Text(getContext().resourceManager.getStringSync($r('app.string.page_home').id))
          .fontSize(TYPOGRAPHY.title_lg.size)
          .fontWeight(TYPOGRAPHY.title_lg.weight)
          .fontColor($r('app.color.text_primary'))

        Blank()

        SymbolGlyph($r('sys.symbol.list_bullet'))
          .fontSize(24)
          .fontColor([$r('app.color.text_secondary')])
          .onClick(() => {
            router.pushUrl({ url: 'pages/SettingsPage' });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      if (this.configs.length === 0) {
        EmptyState({
          title: getContext().resourceManager.getStringSync($r('app.string.empty_config_title').id),
          description: getContext().resourceManager.getStringSync($r('app.string.empty_config_desc').id)
        }) {
          this.EmptyActionBuilder()
        }
      } else {
        Scroll() {
          Column() {
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
                    router.pushUrl({ url: 'pages/TunnelDetailPage', params: { id: cfg.id } });
                  } else {
                    this.selectedConfigId = cfg.id;
                  }
                }
              })
            }

            if (this.diagnostics.length > 0) {
              DiagnosticSummaryCard({ items: this.diagnostics })
            }

            Text(getContext().resourceManager.getStringSync($r('app.string.section_configs').id))
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
                      router.pushUrl({ url: 'pages/TunnelDetailPage', params: { id: config.id } });
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
            .padding({ bottom: SPACING.xxl })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)

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
        .position({ x: 'calc(100% - 72vp)', y: 'calc(100% - 88vp)' })
        .onClick(() => {
          router.pushUrl({ url: 'pages/ImportConfigPage' });
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  DetailPlaceholderColumn() {
    Column() {
      Text('选择一个配置查看详情')
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
  SidebarColumn() {
    Column() {
      Text(getContext().resourceManager.getStringSync($r('app.string.app_name').id))
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

        Text(getContext().resourceManager.getStringSync($r('app.string.page_settings').id))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(44)
      .padding({ left: SPACING.sm, right: SPACING.sm })
      .onClick(() => {
        router.pushUrl({ url: 'pages/SettingsPage' });
      })
    }
    .width('100%')
    .height('100%')
    .padding(SPACING.md)
    .backgroundColor($r('app.color.surface'))
  }

  build() {
    Stack() {
      if (this.breakpoint === Breakpoint.COMPACT) {
        this.ConfigListColumn()
      } else if (this.breakpoint === Breakpoint.MEDIUM) {
        Row() {
          Column() {
            this.ConfigListColumn()
          }
          .width(280)
          .height('100%')

          Divider()
            .vertical(true)
            .strokeWidth(1)
            .color($r('app.color.divider'))

          if (this.selectedConfigId) {
            Column() {
              Text(this.getSelectedConfig()?.name || 'Detail')
                .fontSize(TYPOGRAPHY.title_sm.size)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .padding(SPACING.md)

              Text('平板双栏详情视图')
                .fontSize(TYPOGRAPHY.body_md.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.background'))
            .layoutWeight(1)
          } else {
            Column() {
              this.DetailPlaceholderColumn()
            }
            .layoutWeight(1)
          }
        }
        .width('100%')
        .height('100%')
      } else {
        Row() {
          Column() {
            this.SidebarColumn()
          }
          .width(240)
          .height('100%')

          Divider()
            .vertical(true)
            .strokeWidth(1)
            .color($r('app.color.divider'))

          if (this.selectedConfigId) {
            Column() {
              Text(this.getSelectedConfig()?.name || 'Detail')
                .fontSize(TYPOGRAPHY.title_sm.size)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .padding(SPACING.md)

              Text('PC 大屏三栏详情视图')
                .fontSize(TYPOGRAPHY.body_md.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.background'))
            .layoutWeight(1)
          } else {
            Column() {
              this.DetailPlaceholderColumn()
            }
            .layoutWeight(1)
          }

          Divider()
            .vertical(true)
            .strokeWidth(1)
            .color($r('app.color.divider'))

          Column() {
            Text('诊断与日志')
              .fontSize(TYPOGRAPHY.title_sm.size)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding(SPACING.md)

            Text('常驻诊断面板')
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          .width(320)
          .height('100%')
          .backgroundColor($r('app.color.surface'))
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .onAreaChange((oldArea, newArea) => {
      if (newArea.width > 0) {
        this.windowWidth = px2vp(newArea.width as number);
        this.breakpoint = getBreakpoint(this.windowWidth);
      }
    })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
      .opacity(0)
    PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
      .opacity(1)
  }
}
