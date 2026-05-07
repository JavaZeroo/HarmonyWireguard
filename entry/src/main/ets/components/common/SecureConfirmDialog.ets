import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';

@CustomDialog
export struct SecureConfirmDialog {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop confirmText: string = '';
  @Prop cancelText: string = '';
  @Prop confirmColor: ResourceColor = $r('app.color.danger');

  controller: CustomDialogController;
  onConfirm?: () => void;
  onCancel?: () => void;

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(48)
        .fontColor([$r('app.color.warning')])
        .margin({ bottom: SPACING.md })

      Text(this.title)
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.sm })
        .width('100%')
        .textAlign(TextAlign.Center)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: SPACING.lg })
      }

      Row() {
        Button(this.cancelText || getContext().resourceManager.getStringSync($r('app.string.button_cancel').id))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor('transparent')
          .layoutWeight(1)
          .onClick(() => {
            this.onCancel?.();
            this.controller.close();
          })

        Button(this.confirmText || getContext().resourceManager.getStringSync($r('app.string.button_confirm').id))
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor(this.confirmColor)
          .backgroundColor('transparent')
          .layoutWeight(1)
          .onClick(() => {
            this.onConfirm?.();
            this.controller.close();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SPACING.lg)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.xl)
  }
}
