import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct KeyField {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  @Prop editable: boolean = true;

  onChange?: (val: string) => void;

  private async copyValue(): Promise<void> {
    if (!this.value) {
      return;
    }
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.value);
      await board.setData(data);
      this.getUIContext().getPromptAction().showToast({
        message: getString($r('app.string.hint_copied')),
        duration: 1500
      });
    } catch (e) {
      console.error('KeyField: failed to copy key');
    }
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
            .height(48)
            .backgroundColor('transparent')
            .padding(0)
            .accessibilityText(this.label)
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

        Button(getString($r('app.string.button_copy')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.primary'))
          .backgroundColor('transparent')
          .height(48)
          .enabled(this.value.length > 0)
          .opacity(this.value.length > 0 ? 1 : 0.45)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText($r('app.string.button_copy'))
          .onClick(() => {
            this.copyValue();
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .padding({ left: SPACING.sm, right: SPACING.sm })
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(RADIUS.md)
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
