import { SPACING, RADIUS, SHADOW } from '../../common/DesignSystem';

@Component
export struct SectionCard {
  @Prop title: string = '';
  @Prop cardBackgroundColor: ResourceColor = $r('app.color.surface');
  // 间距由父级 Column({ space }) 统一管理，避免卡片自身 margin 与父级 space 叠加成 32vp。
  @Prop marginTop: number = 0;
  @Prop marginBottom: number = 0;
  @Prop cardPadding: number = SPACING.md;
  @Prop radius: number = RADIUS.lg;
  @Prop showShadow: boolean = true;

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
