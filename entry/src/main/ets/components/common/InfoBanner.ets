import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';

export type BannerType = 'info' | 'warning' | 'danger';

@Component
export struct InfoBanner {
  @Prop message: string = '';
  @Prop type: BannerType = 'info';

  private getBackgroundColor(): ResourceColor {
    switch (this.type) {
      case 'warning':
        return $r('app.color.warning_bg');
      case 'danger':
        return $r('app.color.danger_bg');
      default:
        return $r('app.color.primary_bg');
    }
  }

  private getTextColor(): ResourceColor {
    switch (this.type) {
      case 'warning':
        return $r('app.color.warning');
      case 'danger':
        return $r('app.color.danger');
      default:
        return $r('app.color.primary');
    }
  }

  private getIcon(): Resource {
    switch (this.type) {
      case 'warning':
        return $r('sys.symbol.exclamationmark_triangle');
      case 'danger':
        return $r('sys.symbol.xmark_circle');
      default:
        return $r('sys.symbol.info_circle');
    }
  }

  build() {
    Row() {
      SymbolGlyph(this.getIcon())
        .fontSize(16)
        .fontColor([this.getTextColor()])
        .margin({ right: SPACING.xs })

      Text(this.message)
        .fontSize(TYPOGRAPHY.caption.size)
        .fontColor(this.getTextColor())
        .layoutWeight(1)
    }
    .width('100%')
    .padding(SPACING.sm)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS.sm)
  }
}
