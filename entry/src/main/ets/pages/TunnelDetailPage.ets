import { SPACING, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';

@Component
export struct TunnelDetailPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop navConfigId: string = '';

  build() {
    Column() {
      // Header
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .hoverEffect(HoverEffect.Highlight)
          .onClick(() => {
            this.pageStack.pop();
          })

        Text(getString($r('app.string.page_tunnel_detail')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(24)
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      TunnelDetailPanel({ configId: this.navConfigId })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
