import { router } from '@kit.ArkUI';
import { SPACING, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { TunnelDetailPanel } from '../components/tunnel/TunnelDetailPanel';

@Entry
@Component
struct TunnelDetailPage {
  @State configId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as object;
    const id = (params as Record<string, string>)['id'];
    if (id) {
      this.configId = id;
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            router.back();
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

      TunnelDetailPanel({ configId: this.configId })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
      .opacity(0)
    PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
      .opacity(1)
  }
}
