import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';

@Component
export struct HandshakeCard {
  @Prop lastHandshakeAt: number = -1; // timestamp in seconds

  private getHandshakeText(): string {
    const now = Math.floor(Date.now() / 1000);
    const ago = this.lastHandshakeAt > 0 ? now - this.lastHandshakeAt : -1;
    if (ago < 0) {
      return getString($r('app.string.hint_handshake_never'));
    }
    if (ago < 60) {
      return getString($r('app.string.hint_handshake_ago')).replace('%s', String(ago));
    }
    return getString($r('app.string.hint_handshake_min_ago')).replace('%s', String(Math.floor(ago / 60)));
  }

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(20)
        .fontColor([$r('app.color.text_secondary')])
        .margin({ right: SPACING.sm })

      Column() {
        Text(getString($r('app.string.label_last_handshake')))
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
