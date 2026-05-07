import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { formatHandshake } from '../../common/Formatters';

@Component
export struct HandshakeCard {
  @Prop lastHandshakeAt: number = -1; // timestamp in seconds

  private getHandshakeText(): string {
    const now = Math.floor(Date.now() / 1000);
    const ago = this.lastHandshakeAt > 0 ? now - this.lastHandshakeAt : -1;
    return formatHandshake(ago);
  }

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(20)
        .fontColor([$r('app.color.text_secondary')])
        .margin({ right: SPACING.sm })

      Column() {
        Text('最近握手')
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Text(this.getHandshakeText())
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(SPACING.md)
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(RADIUS.md)
  }
}
