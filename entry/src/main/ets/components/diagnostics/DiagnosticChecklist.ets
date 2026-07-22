import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import type { DiagnosticItem, DiagnosticStatusType } from '../../model/WgConfig';

@Component
export struct DiagnosticChecklist {
  @Prop items: DiagnosticItem[] = [];
  @Prop isRunning: boolean = false;

  onRunAgain?: () => void;

  private getStatusIcon(status: DiagnosticStatusType): Resource {
    if (status === 'pass') {
      return $r('sys.symbol.checkmark_circle');
    } else if (status === 'warning') {
      return $r('sys.symbol.exclamationmark_triangle');
    } else if (status === 'fail') {
      return $r('sys.symbol.xmark_circle');
    } else {
      return $r('sys.symbol.arrow_clockwise');
    }
  }

  private getStatusColor(status: DiagnosticStatusType): ResourceColor {
    if (status === 'pass') {
      return $r('app.color.success');
    } else if (status === 'warning') {
      return $r('app.color.warning');
    } else if (status === 'fail') {
      return $r('app.color.danger');
    } else {
      return $r('app.color.text_tertiary');
    }
  }

  build() {
    Column({ space: SPACING.sm }) {
      Row() {
        Text(getString($r('app.string.section_diagnostics')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button(this.isRunning
          ? getString($r('app.string.label_checking'))
          : getString($r('app.string.button_retry')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.primary'))
          .backgroundColor('transparent')
          .height(48)
          .enabled(!this.isRunning)
          .accessibilityText($r('app.string.button_retry'))
          .onClick(() => {
            this.onRunAgain?.();
          })
      }
      .width('100%')
      .margin({ bottom: SPACING.xs })

      ForEach(this.items, (item: DiagnosticItem) => {
        Row() {
          SymbolGlyph(this.getStatusIcon(item.status))
            .fontSize(18)
            .fontColor([this.getStatusColor(item.status)])
            .margin({ right: SPACING.sm })

          Column() {
            Text(item.title)
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            if (item.description) {
              Text(item.description)
                .fontSize(TYPOGRAPHY.caption.size)
                .fontColor(this.getStatusColor(item.status))
                .width('100%')
                .margin({ top: 2 })
            }

            if (item.suggestion) {
              Text(item.suggestion)
                .fontSize(TYPOGRAPHY.caption.size)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(SPACING.sm)
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.md)
      }, (item: DiagnosticItem) => item.id)
    }
    .width('100%')
  }
}
