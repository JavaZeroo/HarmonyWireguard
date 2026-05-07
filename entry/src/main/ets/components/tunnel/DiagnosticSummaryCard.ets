import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import type { DiagnosticItem } from '../../model/WgConfig';

@Component
export struct DiagnosticSummaryCard {
  @Prop items: DiagnosticItem[] = [];

  private getStatusColor(status: string): ResourceColor {
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

  private getStatusIcon(status: string): Resource {
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

  build() {
    Row({ space: SPACING.md }) {
      ForEach(this.items.slice(0, 4), (item: DiagnosticItem) => {
        Row() {
          SymbolGlyph(this.getStatusIcon(item.status))
            .fontSize(14)
            .fontColor([this.getStatusColor(item.status)])
            .margin({ right: SPACING.xs })

          Text(item.title)
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }, (item: DiagnosticItem) => item.id)
    }
    .width('100%')
    .padding(SPACING.md)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.lg)
  }
}
