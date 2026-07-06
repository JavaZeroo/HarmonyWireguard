import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { deriveRouteMode, parseEndpoint } from '../common/Utils';
import { SectionCard } from '../components/common/SectionCard';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';

@Component
export struct ConfigPreviewPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop navParam: Object | null = null;
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
  @State appeared: boolean = false;

  aboutToAppear(): void {
    const p = this.navParam;
    if (p !== null) {
      const cfg = p as WgConfig;
      if (typeof cfg.privateKey === 'string') {
        this.config = cfg;
      }
    }
    this.risks = this.computeRisks();
  }

  private getRouteModeLabel(): string {
    const mode = deriveRouteMode(this.config.allowedIPs);
    switch (mode) {
      case 'global':
        return getString($r('app.string.route_global'));
      case 'lanOnly':
        return getString($r('app.string.route_lan_only'));
      default:
        return getString($r('app.string.route_custom'));
    }
  }

  private computeRisks(): string[] {
    const risks: string[] = [];
    const allowed = this.config.allowedIPs || '';

    if (allowed.includes('0.0.0.0/0')) {
      risks.push(getString($r('app.string.risk_global_proxy_v4')));
    }
    if (allowed.includes('::/0')) {
      risks.push(getString($r('app.string.risk_global_proxy_v6')));
    }
    if (!this.config.dns || this.config.dns.trim().length === 0) {
      risks.push(getString($r('app.string.risk_no_dns')));
    }
    if (this.config.persistentKeepalive === 0) {
      risks.push(getString($r('app.string.risk_no_keepalive')));
    }
    const ep = parseEndpoint(this.config.endpoint);
    if (ep && !ep.isIPv6 && !/^\d+\.\d+\.\d+\.\d+$/.test(ep.host)) {
      risks.push(getString($r('app.string.risk_domain_endpoint')));
    }
    if (this.config.mtu === 0) {
      risks.push(getString($r('app.string.risk_auto_mtu')));
    }

    return risks;
  }

  private saveConfig(): void {
    if (!this.config.id) {
      this.config.id = Date.now().toString();
    }
    configManager.saveConfig(this.config);
    try {
      this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.toast_saved')), duration: 1500 });
    } catch {}
    this.pageStack.pop();
  }

  @Builder
  InfoRow(label: string, value: string, isMasked: boolean = false) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_sm.size)
        .fontColor($r('app.color.text_secondary'))
        .width('35%')

      Text(isMasked ? getString($r('app.string.hint_key_hidden')) : value)
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
            this.pageStack.pop();
          })

        Text(getString($r('app.string.page_config_preview')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(getString($r('app.string.button_save')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .padding({ left: SPACING.md, right: SPACING.md, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(RADIUS.full)
          .hoverEffect(HoverEffect.Highlight)
          .stateStyles({
            pressed: {
              .opacity(0.82)
            }
          })
          .onClick(() => {
            this.saveConfig();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      Scroll() {
        Column() {
        Column({ space: SPACING.md }) {
          // Name card
          SectionCard({ cardPadding: SPACING.lg }) {
            Column() {
              Text(this.config.name || getString($r('app.string.label_untitled')))
                .fontSize(TYPOGRAPHY.title_md.size)
                .fontWeight(TYPOGRAPHY.title_md.weight)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Text(getString($r('app.string.page_config_preview')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .margin({ top: SPACING.xs })
            }
            .width('100%')
          }

          // Interface
          SectionCard({ title: getString($r('app.string.section_interface')) }) {
            Column() {
              this.InfoRow('Address', this.config.address);
              this.InfoRow('DNS', this.config.dns || getString($r('app.string.label_auto')));
              this.InfoRow('MTU', this.config.mtu > 0 ? String(this.config.mtu) : getString($r('app.string.label_auto')));
              this.InfoRow('PrivateKey', '', true);
            }
            .width('100%')
          }

          // Peer
          SectionCard({ title: getString($r('app.string.section_peer')) }) {
            Column() {
              this.InfoRow('Endpoint', this.config.endpoint);
              this.InfoRow('PublicKey', this.config.peerPublicKey.substring(0, 20) + '...');
              if (this.config.presharedKey) {
                this.InfoRow('PresharedKey', '', true);
              }
              this.InfoRow('Keepalive', this.config.persistentKeepalive > 0 ? this.config.persistentKeepalive + 's' : getString($r('app.string.label_off')));
            }
            .width('100%')
          }

          // Route Mode
          SectionCard({ title: getString($r('app.string.section_route_dns')) }) {
            Column() {
              Row() {
                Text(getString($r('app.string.field_allowed_ips')))
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
            Button(getString($r('app.string.button_edit')))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor($r('app.color.primary'))
              .backgroundColor($r('app.color.surface_subtle'))
              .layoutWeight(1)
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ right: SPACING.sm })
              .hoverEffect(HoverEffect.Highlight)
              .stateStyles({
                pressed: {
                  .opacity(0.82)
                }
              })
              .onClick(() => {
                this.pageStack.pushPath({ name: 'ConfigEdit', param: this.config });
              })

            Button(getString($r('app.string.button_save')))
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.primary'))
              .layoutWeight(1)
              .height(48)
              .borderRadius(RADIUS.md)
              .margin({ left: SPACING.sm })
              .hoverEffect(HoverEffect.Highlight)
              .stateStyles({
                pressed: {
                  .opacity(0.82)
                }
              })
              .onClick(() => {
                this.saveConfig();
              })
          }
          .width('100%')
          .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.lg, bottom: SPACING.xl })
        }
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .padding({ top: SPACING.md, bottom: SPACING.xl })
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 12 })
        .renderGroup(true)
        .onAppear(() => {
          this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
            this.appeared = true;
          });
        })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
