import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';

@Component
export struct KeyField {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  @Prop editable: boolean = true;

  onChange?: (val: string) => void;

  private copyValue(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: getString($r('app.string.hint_copied')),
        duration: 1500
      });
    } catch {}
  }

  build() {
    Column() {
      Text(this.label)
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      Row() {
        if (this.editable) {
          TextInput({ placeholder: this.placeholder, text: this.value })
            .fontSize(TYPOGRAPHY.body_md.size)
            .layoutWeight(1)
            .backgroundColor('transparent')
            .padding(0)
            .onChange((val) => {
              this.onChange?.(val);
            })
        } else {
          Text(this.value)
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Button('Copy')
          .fontSize(12)
          .fontColor($r('app.color.primary'))
          .backgroundColor('transparent')
          .height(32)
          .onClick(() => {
            this.copyValue();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: SPACING.sm, right: SPACING.sm })
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(RADIUS.md)
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
