import { common } from '@kit.AbilityKit';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { settingsService } from '../service/SettingsService';
import type { ThemeMode } from '../service/SettingsService';

@Component
export struct SettingsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  // 作为「设置」Tab 内嵌时为 true：不显示返回箭头（Tab 无返回栈）。
  @Prop embedded: boolean = false;
  @State currentTheme: ThemeMode = 'system';
  private themeOptions: ThemeMode[] = ['system', 'light', 'dark'];

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    settingsService.init(ctx);
    this.currentTheme = settingsService.getTheme();
  }

  private themeLabel(mode: ThemeMode): string {
    if (mode === 'light') {
      return getString($r('app.string.theme_light'));
    }
    if (mode === 'dark') {
      return getString($r('app.string.theme_dark'));
    }
    return getString($r('app.string.theme_system'));
  }

  @Builder
  SwitchRow(label: string, key: string) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: settingsService.getBool(key) })
        .selectedColor($r('app.color.primary'))
        .onChange((val: boolean) => {
          settingsService.setBool(key, val);
        })
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
    .borderRadius(RADIUS.sm)
    .hoverEffect(HoverEffect.Highlight)
    .onClick(onClick)
  }

  // 主题分段选择器：跟随系统 / 浅色 / 深色
  @Builder
  ThemeSegment() {
    Stack({ alignContent: Alignment.Start }) {
      // 滑动指示胶囊：宽 1/3，按选中项索引平移（各段等宽，translate 用自身宽度百分比）。
      // 平移由 onClick 的 animateTo 驱动，选中项在三段间“滑动”而非跳变。
      Row()
        .width('33.33%')
        .height(36)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(RADIUS.sm)
        .shadow({ radius: 4, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 1 })
        .translate({ x: (this.themeOptions.indexOf(this.currentTheme) * 100).toString() + '%' })

      Row() {
        ForEach(this.themeOptions, (mode: ThemeMode) => {
          Text(this.themeLabel(mode))
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontWeight(this.currentTheme === mode ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.currentTheme === mode ? $r('app.color.primary') : $r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(36)
            .onClick(() => {
              this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
                this.currentTheme = mode;
              });
              settingsService.setTheme(mode);
            })
        }, (mode: ThemeMode) => mode)
      }
      .width('100%')
    }
    .width('100%')
    .height(44)
    .padding(4)
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(RADIUS.md)
  }

  build() {
    Column() {
      // Header
      Row() {
        if (!this.embedded) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('app.color.text_primary')])
            .hoverEffect(HoverEffect.Highlight)
            .onClick(() => {
              this.pageStack.pop();
            })
        } else {
          Blank().width(24)
        }

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
        // 居中 + 限宽，避免平板/2in1 上内容被拉得过宽
        Column() {
        Column({ space: SPACING.md }) {
          // Appearance（放最前，主题切换是最常用的）
          SectionCard({ title: getString($r('app.string.section_appearance')) }) {
            Column({ space: SPACING.sm }) {
              this.ThemeSegment()
              this.SwitchRow(getString($r('app.string.option_compact_mode')), 'compactMode')
              this.SwitchRow(getString($r('app.string.option_status_bar_traffic')), 'statusBarTraffic')
            }
            .width('100%')
          }

          // Connection Behavior
          SectionCard({ title: getString($r('app.string.section_connection_behavior')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_auto_connect')), 'autoConnect')
              this.SwitchRow(getString($r('app.string.option_reconnect')), 'reconnectOnNetworkChange')
              this.SwitchRow(getString($r('app.string.option_retry_failure')), 'retryOnFailure')
            }
            .width('100%')
          }

          // Routing & Network
          SectionCard({ title: getString($r('app.string.section_routing_network')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_allow_lan')), 'allowLanAccess')
              this.SwitchRow(getString($r('app.string.option_block_ipv6')), 'blockIpv6Leak')
              this.SwitchRow(getString($r('app.string.option_mtu_auto')), 'defaultMtuAuto')
              this.SwitchRow(getString($r('app.string.option_dns_leak')), 'dnsLeakDetection')
            }
            .width('100%')
          }

          // Privacy & Security
          SectionCard({ title: getString($r('app.string.section_privacy_security')) }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(getString($r('app.string.option_key_reveal_confirm')), 'keyRevealConfirm')
              this.SwitchRow(getString($r('app.string.option_export_confirm')), 'exportConfirm')
              this.SwitchRow(getString($r('app.string.option_auto_clear_clipboard')), 'autoClearClipboard')
              this.SwitchRow(getString($r('app.string.option_log_sanitization')), 'logSanitization')
            }
            .width('100%')
          }

          // About
          SectionCard({ title: getString($r('app.string.page_about')) }) {
            Column({ space: SPACING.xs }) {
              this.NavigationRow(getString($r('app.string.label_version_info')), () => {
                this.pageStack.pushPath({ name: 'About' });
              })
              this.NavigationRow(getString($r('app.string.label_open_source')), () => {
                this.pageStack.pushPath({ name: 'About' });
              })
              this.NavigationRow(getString($r('app.string.label_privacy')), () => {
                this.pageStack.pushPath({ name: 'About' });
              })
            }
            .width('100%')
          }
        }
        .constraintSize({ maxWidth: 720 })
        .width('100%')
        // 底部留白避开毛玻璃 Tab 栏（barOverlap）
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: 88 })
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
