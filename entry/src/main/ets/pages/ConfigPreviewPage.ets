import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY } from '../common/DesignSystem';
import { deriveRouteMode, parseEndpoint } from '../common/Utils';
import { SectionCard } from '../components/common/SectionCard';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';

@Entry
@Component
struct ConfigPreviewPage {
  @State risks: string[] = [];
  @State config: WgConfig = {
    id: '',
    name: '',
    privateKey: '',
    address: '',
    dns: '',
    mtu: 0,
    peerPublicKey: '',
    presharedKey: '',
    allowedIPs: '',
    endpoint: '',
    persistentKeepalive: 0
  };

  aboutToAppear(): void {
    const params = router.getParams() as object;
    const cfg = (params as Record<string, WgConfig>)['config'];
    if (cfg) {
      this.config = cfg;
    }
    this.risks = this.computeRisks();
  }

  private getRouteModeLabel(): string {
    const mode = deriveRouteMode(this.config.allowedIPs);
    const rm = getContext().resourceManager;
    switch (mode) {
      case 'global':
        return rm.getStringSync($r('app.string.route_global').id);
      case 'lanOnly':
        return rm.getStringSync($r('app.string.route_lan_only').id);
      default:
        return rm.getStringSync($r('app.string.route_custom').id);
    }
  }

  private computeRisks(): string[] {
    const risks: string[] = [];
    const rm = getContext().resourceManager;
    const allowed = this.config.allowedIPs || '';

    if (allowed.includes('0.0.0.0/0')) {
      risks.push(rm.getStringSync($r('app.string.risk_global_proxy_v4').id));
    }
    if (allowed.includes('::/0')) {
      risks.push(rm.getStringSync($r('app.string.risk_global_proxy_v6').id));
    }
    if (!this.config.dns || this.config.dns.trim().length === 0) {
      risks.push(rm.getStringSync($r('app.string.risk_no_dns').id));
    }
    if (this.config.persistentKeepalive === 0) {
      risks.push(rm.getStringSync($r('app.string.risk_no_keepalive').id));
    }
    const ep = parseEndpoint(this.config.endpoint);
    if (ep && !ep.isIPv6 && !/^\d+\.\d+\.\d+\.\d+$/.test(ep.host)) {
      risks.push(rm.getStringSync($r('app.string.risk_domain_endpoint').id));
    }
    if (this.config.mtu === 0) {
      risks.push(rm.getStringSync($r('app.string.risk_auto_mtu').id));
    }

    return risks;
  }

  private saveConfig(): void {
    if (!this.config.id) {
      this.config.id = Date.now().toString();
    }
    configManager.saveConfig(this.config);
    promptAction.showToast({ message: 'Saved', duration: 1500 });
    router.back();
  }

  @Builder
  InfoRow(label: string, value: string, isMasked: boolean = false) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_sm.size)
        .fontColor($r('app.color.text_secondary'))
        .width('35%')

      Text(isMasked ? getContext().resourceManager.getStringSync($r('app.string.hint_key_hidden').id) : value)
        .fontSize(TYPOGRAPHY.body_sm.size)
        .fontColor(isMasked ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: SPACING.xs, bottom: SPACING.xs })
  }

  build() {
    Column() {
      // Header
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            router.back();
          })

        Text(getContext().resourceManager.getStringSync($r('app.string.page_config_preview').id))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(getContext().resourceManager.getStringSync($r('app.string.button_save').id))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.saveConfig();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      Scroll() {
        Column({ space: SPACING.md }) {
          // Name card
          SectionCard({ cardPadding: SPACING.lg }) {
            Column() {
              Text(this.config.name || 'Untitled')
                .fontSize(TYPOGRAPHY.title_md.size)
                .fontWeight(TYPOGRAPHY.title_md.weight)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Text(getContext().resourceManager.getStringSync($r('app.string.page_config_preview').id))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .margin({ top: SPACING.xs })
            }
            .width('100%')
          }

          // Interface
          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_interface').id) }) {
            Column() {
              this.InfoRow('Address', this.config.address);
              this.InfoRow('DNS', this.config.dns || 'Auto');
              this.InfoRow('MTU', this.config.mtu > 0 ? String(this.config.mtu) : 'Auto');
              this.InfoRow('PrivateKey', '', true);
            }
            .width('100%')
          }

          // Peer
          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_peer').id) }) {
            Column() {
              this.InfoRow('Endpoint', this.config.endpoint);
              this.InfoRow('PublicKey', this.config.peerPublicKey.substring(0, 20) + '...');
              if (this.config.presharedKey) {
                this.InfoRow('PresharedKey', '', true);
              }
              this.InfoRow('Keepalive', this.config.persistentKeepalive > 0 ? this.config.persistentKeepalive + 's' : 'Off');
            }
            .width('100%')
          }

          // Route Mode
          SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_route_dns').id) }) {
            Column() {
              Row() {
                Text(getContext().resourceManager.getStringSync($r('app.string.field_allowed_ips').id))
                  .fontSize(TYPOGRAPHY.body_sm.size)
                  .fontColor($r('app.color.text_secondary'))
                  .width('35%')

                Text(this.getRouteModeLabel())
                  .fontSize(TYPOGRAPHY.body_sm.size)
                  .fontColor($r('app.color.primary'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ top: SPACING.xs, bottom: SPACING.xs })

              Text(this.config.allowedIPs)
                .fontSize(TYPOGRAPHY.caption.size)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .textAlign(TextAlign.End)
                .margin({ top: SPACING.xs })
            }
            .width('100%')
          }

          // Risks
          if (this.risks.length > 0) {
            Column({ space: SPACING.xs }) {
              ForEach(this.risks, (risk: string) => {
                Row() {
                  SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                    .fontSize(14)
                    .fontColor([$r('app.color.warning')])
                    .margin({ right: SPACING.xs })

                  Text(risk)
                    .fontSize(TYPOGRAPHY.caption.size)
                    .fontColor($r('app.color.warning'))
                    .layoutWeight(1)
                }
                .width('100%')
                .padding(SPACING.sm)
                .backgroundColor($r('app.color.warning_bg'))
                .borderRadius(RADIUS.sm)
              }, (risk: string) => risk)
            }
            .width('100%')
            .padding({ left: SPACING.md, right: SPACING.md })
          }

          // Actions
          Row() {
            Button(getContext().resourceManager.getStringSync($r('app.string.button_edit').id))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor($r('app.color.primary'))
              .backgroundColor($r('app.color.surface_subtle'))
              .layoutWeight(1)
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ right: SPACING.sm })
              .onClick(() => {
                router.pushUrl({ url: 'pages/ConfigEditPage', params: { config: this.config } });
              })

            Button(getContext().resourceManager.getStringSync($r('app.string.button_save').id))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.primary'))
              .layoutWeight(1)
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ left: SPACING.sm })
              .onClick(() => {
                this.saveConfig();
              })
          }
          .width('100%')
          .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.lg, bottom: SPACING.xl })
        }
        .width('100%')
        .padding({ top: SPACING.md, bottom: SPACING.xl })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
      .opacity(0)
    PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
      .opacity(1)
  }
}
