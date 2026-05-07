import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY } from '../common/DesignSystem';
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

        Text(getContext().resourceManager.getStringSync($r('app.string.page_settings').id))
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
          SectionCard({ title: '连接行为' }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow('启动时自动连接', this.autoConnect, (v) => this.autoConnect = v)
              this.SwitchRow('网络变化后自动重连', this.reconnectOnNetworkChange, (v) => this.reconnectOnNetworkChange = v)
              this.SwitchRow('连接失败自动重试', this.retryOnFailure, (v) => this.retryOnFailure = v)
            }
            .width('100%')
          }

          // Routing & Network
          SectionCard({ title: '路由与网络' }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow('允许访问本地网络', this.allowLanAccess, (v) => this.allowLanAccess = v)
              this.SwitchRow('IPv6 防泄露', this.blockIpv6Leak, (v) => this.blockIpv6Leak = v)
              this.SwitchRow('默认 MTU 自动', this.defaultMtuAuto, (v) => this.defaultMtuAuto = v)
              this.SwitchRow('DNS 泄漏检测', this.dnsLeakDetection, (v) => this.dnsLeakDetection = v)
            }
            .width('100%')
          }

          // Privacy & Security
          SectionCard({ title: '隐私与安全' }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow('私钥显示二次确认', this.keyRevealConfirm, (v) => this.keyRevealConfirm = v)
              this.SwitchRow('导出配置二次确认', this.exportConfirm, (v) => this.exportConfirm = v)
              this.SwitchRow('自动清除剪贴板', this.autoClearClipboard, (v) => this.autoClearClipboard = v)
              this.SwitchRow('日志脱敏', this.logSanitization, (v) => this.logSanitization = v)
            }
            .width('100%')
          }

          // Appearance
          SectionCard({ title: '外观' }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow('跟随系统深色模式', this.followSystemDark, (v) => this.followSystemDark = v)
              this.SwitchRow('紧凑模式', this.compactMode, (v) => this.compactMode = v)
              this.SwitchRow('状态栏显示流量', this.statusBarTraffic, (v) => this.statusBarTraffic = v)
            }
            .width('100%')
          }

          // About
          SectionCard({ title: '关于' }) {
            Column({ space: SPACING.xs }) {
              this.NavigationRow('版本信息', () => {
                router.pushUrl({ url: 'pages/AboutPage' });
              })
              this.NavigationRow('开源协议', () => {
                router.pushUrl({ url: 'pages/AboutPage' });
              })
              this.NavigationRow('隐私说明', () => {
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
