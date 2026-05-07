import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';

@Component
export struct ExportReportButton {
  onExport?: () => void;

  private handleExport(): void {
    this.onExport?.();
    try {
      this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.toast_report_exported')), duration: 2000 });
    } catch {}
  }

  build() {
    Button() {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(16)
          .fontColor(['#FFFFFF'])
          .margin({ right: SPACING.xs })

        Text(getString($r('app.string.button_export_report')))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor('#FFFFFF')
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor($r('app.color.primary'))
    .borderRadius(RADIUS.md)
    .margin({ top: SPACING.md })
    .onClick(() => this.handleExport())
  }
}
