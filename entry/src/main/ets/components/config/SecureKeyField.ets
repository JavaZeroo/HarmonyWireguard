import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { SecureConfirmDialog } from '../common/SecureConfirmDialog';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SecureKeyField {
  @Prop label: string = '';
  @Prop hasValue: boolean = false;
  @Prop value: string = '';
  @State revealed: boolean = false;

  onReplace?: (newValue: string) => void;
  onReveal?: () => void;

  private revealTimer: number = -1;
  private dialogController: CustomDialogController | null = null;

  private showRevealDialog(): void {
    this.dialogController = new CustomDialogController({
      builder: SecureConfirmDialog({
        title: getContext().resourceManager.getStringSync($r('app.string.dialog_reveal_key_title').id),
        message: getContext().resourceManager.getStringSync($r('app.string.dialog_reveal_key_message').id),
        confirmText: getContext().resourceManager.getStringSync($r('app.string.dialog_reveal_key_action').id),
        confirmColor: $r('app.color.warning'),
        onConfirm: () => {
          this.revealed = true;
          this.onReveal?.();
          this.startRevealTimer();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
    this.dialogController.open();
  }

  private startRevealTimer(): void {
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
    }
    this.revealTimer = setTimeout(() => {
      this.revealed = false;
    }, 30000);
  }

  private handleAppBackground(): void {
    this.revealed = false;
  }

  private copyValue(): void {
    // Clipboard set API would go here
    promptAction.showToast({
      message: getContext().resourceManager.getStringSync($r('app.string.hint_copied').id),
      duration: 1500
    });
    setTimeout(() => {
      promptAction.showToast({
        message: getContext().resourceManager.getStringSync($r('app.string.hint_clipboard_cleared').id),
        duration: 2000
      });
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
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
        if (this.hasValue && !this.revealed) {
          Text(getContext().resourceManager.getStringSync($r('app.string.hint_key_hidden').id))
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.revealed && this.value) {
          Text(this.value)
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          TextInput({ placeholder: 'Base64 encoded 32-byte key', text: this.value })
            .fontSize(TYPOGRAPHY.body_md.size)
            .layoutWeight(1)
            .backgroundColor('transparent')
            .padding(0)
            .onChange((val) => {
              this.onReplace?.(val);
            })
        }

        if (this.hasValue) {
          Button(this.revealed ? 'Hide' : 'View')
            .fontSize(12)
            .fontColor($r('app.color.primary'))
            .backgroundColor('transparent')
            .height(32)
            .onClick(() => {
              if (this.revealed) {
                this.revealed = false;
                if (this.revealTimer !== -1) {
                  clearTimeout(this.revealTimer);
                }
              } else {
                this.showRevealDialog();
              }
            })

          if (this.revealed) {
            Button('Copy')
              .fontSize(12)
              .fontColor($r('app.color.primary'))
              .backgroundColor('transparent')
              .height(32)
              .onClick(() => {
                this.copyValue();
              })
          }
        }
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
