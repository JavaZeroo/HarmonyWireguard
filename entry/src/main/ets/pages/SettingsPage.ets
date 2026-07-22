import { common } from '@kit.AbilityKit';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { PageHeader } from '../components/app/PageHeader';
import { settingsService } from '../service/SettingsService';
import type { BoolSettingKey, ThemeMode } from '../service/SettingsService';

@Component
export struct SettingsPage {
  pageStack: NavPathStack = new NavPathStack();
  // 作为「设置」Tab 内嵌时为 true：不显示返回箭头（Tab 无返回栈）。
  @Prop embedded: boolean = false;
  @Prop bottomInset: number = 88;
  @State currentTheme: ThemeMode = 'system';
  @State compactMode: boolean = false;
  @State keyRevealConfirm: boolean = true;
  @State reportCopyConfirm: boolean = true;
  @State autoClearClipboard: boolean = true;
  private themeOptions: ThemeMode[] = ['system', 'light', 'dark'];

  onCompactModeChange?: (isCompact: boolean) => void;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    settingsService.init(ctx);
    this.currentTheme = settingsService.getTheme();
    this.compactMode = settingsService.getBool('compactMode');
    this.keyRevealConfirm = settingsService.getBool('keyRevealConfirm');
    this.reportCopyConfirm = settingsService.getBool('reportCopyConfirm');
    this.autoClearClipboard = settingsService.getBool('autoClearClipboard');
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch {}
  }

  private updateBoolSetting(key: BoolSettingKey, value: boolean): void {
    if (!settingsService.setBool(key, value)) {
      this.showToast(getString($r('app.string.error_save_setting')));
      return;
    }
    if (key === 'compactMode') {
      this.compactMode = value;
      this.onCompactModeChange?.(value);
    } else if (key === 'keyRevealConfirm') {
      this.keyRevealConfirm = value;
    } else if (key === 'reportCopyConfirm') {
      this.reportCopyConfirm = value;
    } else if (key === 'autoClearClipboard') {
      this.autoClearClipboard = value;
    }
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
  SwitchRow(label: string, key: BoolSettingKey, value: boolean) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.primary'))
        .accessibilityText(label)
        .onChange((val: boolean) => {
          this.updateBoolSetting(key, val);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ top: SPACING.xs, bottom: SPACING.xs })
  }

  @Builder
  StatusRow(label: string, status: string) {
    Row({ space: SPACING.sm }) {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(2)

      Row({ space: SPACING.xs }) {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(16)
          .fontColor([$r('app.color.success')])
        Text(status)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.success'))
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ top: SPACING.xs, bottom: SPACING.xs })
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
    .constraintSize({ minHeight: 48 })
    .padding({ top: SPACING.xs, bottom: SPACING.xs })
    .borderRadius(RADIUS.sm)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
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
        .height(40)
        .margin({ top: 4 })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(RADIUS.sm)
        .shadow({ radius: 4, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 1 })
        .translate({ x: (this.themeOptions.indexOf(this.currentTheme) * 100).toString() + '%' })

      Row() {
        ForEach(this.themeOptions, (mode: ThemeMode) => {
          Row() {
            Text(this.themeLabel(mode))
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontWeight(this.currentTheme === mode ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.currentTheme === mode ? $r('app.color.primary') : $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .maxLines(1)
          }
          .layoutWeight(1)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(this.themeLabel(mode))
          .accessibilityDescription(this.currentTheme === mode
            ? getString($r('app.string.accessibility_selected')) : '')
          .onClick(() => {
            if (settingsService.setTheme(mode)) {
              this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
                this.currentTheme = mode;
              });
            } else {
              this.showToast(getString($r('app.string.error_save_setting')));
            }
          })
        }, (mode: ThemeMode) => mode)
      }
      .width('100%')
    }
    .width('100%')
    .height(48)
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(RADIUS.md)
  }

  build() {
    Column() {
      PageHeader({
        pageStack: this.pageStack,
        title: getString($r('app.string.page_settings')),
        showBack: !this.embedded
      })

      Scroll() {
        // 居中 + 限宽，避免平板/2in1 上内容被拉得过宽
        Column() {
        Column({ space: this.compactMode ? SPACING.sm : SPACING.md }) {
          // Appearance（放最前，主题切换是最常用的）
          SectionCard({
            title: getString($r('app.string.section_appearance')),
            cardPadding: this.compactMode ? SPACING.sm : SPACING.md
          }) {
            Column({ space: SPACING.sm }) {
              this.ThemeSegment()
              this.SwitchRow(
                getString($r('app.string.option_compact_mode')),
                'compactMode',
                this.compactMode
              )
            }
            .width('100%')
          }

          // Privacy & Security
          SectionCard({
            title: getString($r('app.string.section_privacy_security')),
            cardPadding: this.compactMode ? SPACING.sm : SPACING.md
          }) {
            Column({ space: SPACING.xs }) {
              this.SwitchRow(
                getString($r('app.string.option_key_reveal_confirm')),
                'keyRevealConfirm',
                this.keyRevealConfirm
              )
              this.SwitchRow(
                getString($r('app.string.option_report_copy_confirm')),
                'reportCopyConfirm',
                this.reportCopyConfirm
              )
              this.SwitchRow(
                getString($r('app.string.option_auto_clear_clipboard')),
                'autoClearClipboard',
                this.autoClearClipboard
              )
              this.StatusRow(
                getString($r('app.string.option_log_sanitization')),
                getString($r('app.string.label_always_on'))
              )
            }
            .width('100%')
          }

          // About
          SectionCard({
            title: getString($r('app.string.page_about')),
            cardPadding: this.compactMode ? SPACING.sm : SPACING.md
          }) {
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
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: this.bottomInset })
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
