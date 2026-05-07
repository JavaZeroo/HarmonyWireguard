import { SPACING, RADIUS, SHADOW } from '../../common/DesignSystem';

@Component
export struct SectionCard {
  @Prop title: string = '';
  @Prop cardBackgroundColor: ResourceColor = $r('app.color.surface');
  @Prop marginTop: number = SPACING.md;
  @Prop marginBottom: number = 0;
  @Prop cardPadding: number = SPACING.md;
  @Prop radius: number = RADIUS.lg;
  @Prop showShadow: boolean = false;

  @BuilderParam
  contentBuilder: () => void = this.defaultContent;

  @Builder
  defaultContent() {
    Column() {}
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: SPACING.sm })
          .width('100%')
      }
      this.contentBuilder()
    }
    .width('100%')
    .padding(this.cardPadding)
    .backgroundColor(this.cardBackgroundColor)
    .borderRadius(this.radius)
    .margin({ top: this.marginTop, bottom: this.marginBottom })
    .shadow(this.showShadow ? SHADOW.sm : undefined)
  }
}
