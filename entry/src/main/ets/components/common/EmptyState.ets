import { SPACING, TYPOGRAPHY } from '../../common/DesignSystem';

@Component
export struct EmptyState {
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop description: string = '';

  @BuilderParam
  actionBuilder: () => void = this.defaultAction;

  @Builder
  defaultAction() {
    Column() {}
  }

  build() {
    Column() {
      if (this.icon) {
        SymbolGlyph($r('sys.symbol.wifi_slash'))
          .fontSize(64)
          .fontColor([$r('app.color.text_tertiary')])
          .margin({ bottom: SPACING.lg })
      }

      Text(this.title)
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(TYPOGRAPHY.title_sm.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.sm })

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: SPACING.lg })
          .padding({ left: SPACING.xl, right: SPACING.xl })
      }

      this.actionBuilder()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
