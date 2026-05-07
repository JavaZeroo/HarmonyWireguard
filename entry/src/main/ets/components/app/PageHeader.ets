import { SPACING, TYPOGRAPHY } from '../../common/DesignSystem';
import { router } from '@kit.ArkUI';

@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop showBack: boolean = true;

  @BuilderParam
  trailingBuilder: () => void = this.defaultTrailing;

  @Builder
  defaultTrailing() {
    Blank().width(24)
  }

  build() {
    Row() {
      if (this.showBack) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            router.back();
          })
      } else {
        Blank().width(24)
      }

      Text(this.title)
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(TYPOGRAPHY.title_sm.weight)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      this.trailingBuilder()
    }
    .width('100%')
    .height(56)
    .padding({ left: SPACING.md, right: SPACING.md })
    .backgroundColor($r('app.color.surface'))
  }
}
