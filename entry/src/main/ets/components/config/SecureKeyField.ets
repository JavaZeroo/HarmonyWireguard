import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { DialogHelper } from '../../common/DialogHelper';

@Component
export struct SecureKeyField {
  @Prop label: string = '';
  @Prop hasValue: boolean = false;
  @Prop value: string = '';
  @State revealed: boolean = false;

  onReplace?: (newValue: string) => void;
  onReveal?: () => void;

  private revealTimer: number = -1;

  private showRevealDialog(): void {
    DialogHelper.showConfirm(this.getUIContext(), {
      title: getString($r('app.string.dialog_reveal_key_title')),
      message: getString($r('app.string.dialog_reveal_key_message')),
      confirmText: getString($r('app.string.dialog_reveal_key_action')),
      confirmColor: $r('app.color.warning'),
      secure: true,
      onConfirm: () => {
        this.revealed = true;
        this.onReveal?.();
        this.startRevealTimer();
      }
    });
  }

  private startRevealTimer(): void {
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
    }
    this.revealTimer = setTimeout(() => {
      this.revealed = false;
    }, 30000);
  }

  private copyValue(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: getString($r('app.string.hint_copied')),
        duration: 1500
      });
    } catch {}
    setTimeout(() => {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: getString($r('app.string.hint_clipboard_cleared')),
          duration: 2000
        });
      } catch {}
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
          Text(getString($r('app.string.hint_key_hidden')))
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
          TextInput({ placeholder: getString($r('app.string.placeholder_private_key')), text: this.value })
            .fontSize(TYPOGRAPHY.body_md.size)
            .layoutWeight(1)
            .backgroundColor('transparent')
            .padding(0)
            .onChange((val) => {
              this.onReplace?.(val);
            })
        }

        if (this.hasValue) {
          Button(this.revealed ? getString($r('app.string.button_hide')) : getString($r('app.string.button_view')))
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
            Button(getString($r('app.string.button_copy')))
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
