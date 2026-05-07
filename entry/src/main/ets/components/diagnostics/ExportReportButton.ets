import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { promptAction } from '@kit.ArkUI';

@Component
export struct ExportReportButton {
  onExport?: () => void;

  private handleExport(): void {
    this.onExport?.();
    promptAction.showToast({ message: '诊断报告已导出（脱敏）', duration: 2000 });
  }

  build() {
    Button() {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(16)
          .fontColor(['#FFFFFF'])
          .margin({ right: SPACING.xs })

        Text(getContext().resourceManager.getStringSync($r('app.string.button_export_report').id))
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
