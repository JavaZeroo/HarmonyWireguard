import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';

@Entry
@Component
struct SettingsPage {
  @State autoConnect: boolean = false;
  @State reconnectOnNetworkChange: boolean = true;
  @State retryOnFailure: boolean = true;
  @State allowLanAccess: boolean = true;
  @State blockIpv6Leak: boolean = true;
  @State defaultMtuAuto: boolean = true;
  @State dnsLeakDetection: boolean = false;
  @State keyRevealConfirm: boolean = true;
  @State exportConfirm: boolean = true;
  @State autoClearClipboard: boolean = true;
  @State logSanitization: boolean = true;
  @State followSystemDark: boolean = true;
  @State compactMode: boolean = false;
  @State statusBarTraffic: boolean = false;

  @Builder
  SwitchRow(label: string, checked: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor($r('app.color.primary'))
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
  }

  @Builder
  NavigationRow(label: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .height(48)
    .onClick(onClick)
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

        Text(getString($r('app.string.page_settings')))
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

      Scroll() {
        Column({ space: SPACING.md }) {
          // Connection Behavior
          SectionCard({ title: getString($r('app.string.section_connection_behavior')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_auto_connect')), this.autoConnect, (v) => this.autoConnect = v)
              this.SwitchRow(getString($r('app.string.option_reconnect')), this.reconnectOnNetworkChange, (v) => this.reconnectOnNetworkChange = v)
              this.SwitchRow(getString($r('app.string.option_retry_failure')), this.retryOnFailure, (v) => this.retryOnFailure = v)
            }
            .width('100%')
          }

          // Routing & Network
          SectionCard({ title: getString($r('app.string.section_routing_network')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_allow_lan')), this.allowLanAccess, (v) => this.allowLanAccess = v)
              this.SwitchRow(getString($r('app.string.option_block_ipv6')), this.blockIpv6Leak, (v) => this.blockIpv6Leak = v)
              this.SwitchRow(getString($r('app.string.option_mtu_auto')), this.defaultMtuAuto, (v) => this.defaultMtuAuto = v)
              this.SwitchRow(getString($r('app.string.option_dns_leak')), this.dnsLeakDetection, (v) => this.dnsLeakDetection = v)
            }
            .width('100%')
          }

          // Privacy & Security
          SectionCard({ title: getString($r('app.string.section_privacy_security')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_key_reveal_confirm')), this.keyRevealConfirm, (v) => this.keyRevealConfirm = v)
              this.SwitchRow(getString($r('app.string.option_export_confirm')), this.exportConfirm, (v) => this.exportConfirm = v)
              this.SwitchRow(getString($r('app.string.option_auto_clear_clipboard')), this.autoClearClipboard, (v) => this.autoClearClipboard = v)
              this.SwitchRow(getString($r('app.string.option_log_sanitization')), this.logSanitization, (v) => this.logSanitization = v)
            }
            .width('100%')
          }

          // Appearance
          SectionCard({ title: getString($r('app.string.section_appearance')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_follow_dark')), this.followSystemDark, (v) => this.followSystemDark = v)
              this.SwitchRow(getString($r('app.string.option_compact_mode')), this.compactMode, (v) => this.compactMode = v)
              this.SwitchRow(getString($r('app.string.option_status_bar_traffic')), this.statusBarTraffic, (v) => this.statusBarTraffic = v)
            }
            .width('100%')
          }

          // About
          SectionCard({ title: getString($r('app.string.page_about')) }) {
            Column({ space: SPACING.xs }) {
              this.NavigationRow(getString($r('app.string.label_version_info')), () => {
                router.pushUrl({ url: 'pages/AboutPage' });
              })
              this.NavigationRow(getString($r('app.string.label_open_source')), () => {
                router.pushUrl({ url: 'pages/AboutPage' });
              })
              this.NavigationRow(getString($r('app.string.label_privacy')), () => {
                router.pushUrl({ url: 'pages/AboutPage' });
              })
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
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
