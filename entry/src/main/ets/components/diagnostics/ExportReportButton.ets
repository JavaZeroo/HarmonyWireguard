import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { DialogHelper } from '../../common/DialogHelper';
import { settingsService } from '../../service/SettingsService';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct ExportReportButton {
  onExport?: () => string;

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch {}
  }

  private async copyReport(report: string): Promise<void> {
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, report);
      await board.setData(data);
      this.showToast(getString($r('app.string.toast_report_copied')));
    } catch {
      this.showToast(getString($r('app.string.error_export_report')));
    }
  }

  private handleExport(): void {
    const report = this.onExport?.() ?? '';
    if (!report.trim()) {
      this.showToast(getString($r('app.string.error_export_report')));
      return;
    }
    if (!settingsService.getBool('reportCopyConfirm')) {
      this.copyReport(report);
      return;
    }
    DialogHelper.showConfirm(this.getUIContext(), {
      title: getString($r('app.string.dialog_copy_report_title')),
      message: getString($r('app.string.dialog_copy_report_message')),
      confirmText: getString($r('app.string.button_copy_report')),
      confirmColor: $r('app.color.primary'),
      onConfirm: () => {
        this.copyReport(report);
      }
    });
  }

  build() {
    Button() {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(16)
          .fontColor(['#FFFFFF'])
          .margin({ right: SPACING.xs })

        Text(getString($r('app.string.button_copy_report')))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor('#FFFFFF')
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor($r('app.color.primary'))
    .borderRadius(RADIUS.md)
    .margin({ top: SPACING.md })
    .accessibilityText($r('app.string.button_copy_report'))
    .onClick(() => {
      this.handleExport();
    })
  }
}
