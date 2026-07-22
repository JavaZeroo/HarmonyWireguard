import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { DialogHelper } from '../../common/DialogHelper';
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { settingsService } from '../../service/SettingsService';
import { APP_CONSTANTS } from '../../common/Constants';

const CLIPBOARD_CLEAR_DELAY_MS = 30000;

@Component
export struct SecureKeyField {
  @Prop label: string = '';
  @Prop hasValue: boolean = false;
  @Prop value: string = '';
  @State revealed: boolean = false;
  @State isEditing: boolean = true;
  @State draftValue: string = '';

  onReplace?: (newValue: string) => void;
  onReveal?: () => void;

  private revealTimer: number = -1;
  private clipboardClearTimer: number = -1;
  private originalValue: string = '';
  private isVisible: boolean = false;
  private backgroundHandler: () => void = () => {
    this.hideSensitiveValue();
  };

  aboutToAppear(): void {
    this.isVisible = true;
    this.revealed = false;
    this.originalValue = this.value;
    this.draftValue = this.value;
    // A new key stays editable while the parent reflects each typed character
    // back through hasValue/value. Existing keys start in the protected view.
    this.isEditing = !this.hasValue;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.on(APP_CONSTANTS.APP_BACKGROUND_EVENT, this.backgroundHandler);
  }

  private hideSensitiveValue(): void {
    this.revealed = false;
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
  }

  private revealValue(): void {
    this.revealed = true;
    this.onReveal?.();
    this.startRevealTimer();
  }

  private showRevealDialog(): void {
    if (!settingsService.getBool('keyRevealConfirm')) {
      this.revealValue();
      return;
    }
    DialogHelper.showConfirm(this.getUIContext(), {
      title: getString($r('app.string.dialog_reveal_key_title')),
      message: getString($r('app.string.dialog_reveal_key_message')),
      confirmText: getString($r('app.string.dialog_reveal_key_action')),
      confirmColor: $r('app.color.warning'),
      secure: true,
      onConfirm: () => {
        this.revealValue();
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

  private showToast(message: string, duration: number = 1500): void {
    if (!this.isVisible) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        duration
      });
    } catch {}
  }

  private actionAccessibilityText(action: Resource): string {
    return this.label + ': ' + getString(action);
  }

  private scheduleClipboardClear(changeCount: number): void {
    if (this.clipboardClearTimer !== -1) {
      clearTimeout(this.clipboardClearTimer);
    }
    this.clipboardClearTimer = setTimeout(() => {
      this.clipboardClearTimer = -1;
      this.clearClipboardIfUnchanged(changeCount);
    }, CLIPBOARD_CLEAR_DELAY_MS);
  }

  private async clearClipboardIfUnchanged(changeCount: number): Promise<void> {
    try {
      const board = pasteboard.getSystemPasteboard();
      // Avoid reading clipboard contents (and avoid READ_PASTEBOARD). The
      // monotonic change counter also prevents erasing something the user
      // copied after this key.
      if (board.getChangeCount() === changeCount) {
        await board.clearData();
        this.showToast(getString($r('app.string.hint_clipboard_cleared')), 2000);
      }
    } catch (e) {
      console.error('SecureKeyField: failed to clear clipboard');
    }
  }

  private async copyValue(): Promise<void> {
    if (!this.value) {
      return;
    }
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.value);
      await board.setData(data);
      this.showToast(getString($r('app.string.hint_copied')));
      if (settingsService.getBool('autoClearClipboard')) {
        this.scheduleClipboardClear(board.getChangeCount());
      }
    } catch (e) {
      console.error('SecureKeyField: failed to copy key');
    }
  }

  private beginReplace(): void {
    this.originalValue = this.value;
    this.draftValue = '';
    this.revealed = false;
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
    this.isEditing = true;
    this.onReplace?.('');
  }

  private updateDraft(value: string): void {
    this.draftValue = value;
    this.onReplace?.(value);
  }

  private confirmEditing(): void {
    if (!this.draftValue) {
      return;
    }
    this.originalValue = this.draftValue;
    this.isEditing = false;
    this.revealed = false;
  }

  private cancelEditing(): void {
    this.draftValue = this.originalValue;
    this.onReplace?.(this.originalValue);
    this.isEditing = false;
    this.revealed = false;
  }

  aboutToDisappear(): void {
    this.isVisible = false;
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.off(APP_CONSTANTS.APP_BACKGROUND_EVENT, this.backgroundHandler);
    // Do not cancel clipboardClearTimer here. Sensitive text must still be
    // cleared after leaving the page, provided the user has not copied
    // something else in the meantime.
  }

  build() {
    Column() {
      Text(this.label)
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      if (this.isEditing) {
        Column({ space: SPACING.xs }) {
          TextInput({
            placeholder: getString($r('app.string.placeholder_private_key')),
            text: this.draftValue
          })
            .fontSize(TYPOGRAPHY.body_md.size)
            .width('100%')
            .height(48)
            .type(InputType.Password)
            .backgroundColor(Color.Transparent)
            .padding({ left: SPACING.sm, right: SPACING.sm })
            .accessibilityText(this.label)
            .onChange((val: string) => {
              this.updateDraft(val);
            })

          Row({ space: SPACING.xs }) {
            Blank()
            if (this.originalValue.length > 0) {
              Button(getString($r('app.string.button_cancel')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor(Color.Transparent)
                .height(48)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText(this.actionAccessibilityText($r('app.string.button_cancel')))
                .onClick(() => {
                  this.cancelEditing();
                })
            }
            Button(getString($r('app.string.button_confirm')))
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.primary'))
              .backgroundColor(Color.Transparent)
              .height(48)
              .enabled(this.draftValue.length > 0)
              .opacity(this.draftValue.length > 0 ? 1 : 0.45)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText(this.actionAccessibilityText($r('app.string.button_confirm')))
              .onClick(() => {
                this.confirmEditing();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: SPACING.xs, right: SPACING.xs })
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.md)
      } else {
        Row() {
          Text(this.revealed ? this.value : getString($r('app.string.hint_key_hidden')))
            .fontSize(this.revealed ? TYPOGRAPHY.body_sm.size : TYPOGRAPHY.body_md.size)
            .fontColor(this.revealed ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Button(this.revealed ? getString($r('app.string.button_hide')) : getString($r('app.string.button_view')))
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontColor($r('app.color.primary'))
            .backgroundColor(Color.Transparent)
            .height(48)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.actionAccessibilityText(this.revealed
              ? $r('app.string.button_hide') : $r('app.string.button_view')))
            .onClick(() => {
              if (this.revealed) {
                this.revealed = false;
                if (this.revealTimer !== -1) {
                  clearTimeout(this.revealTimer);
                  this.revealTimer = -1;
                }
              } else {
                this.showRevealDialog();
              }
            })

          Button(getString($r('app.string.button_replace')))
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontColor($r('app.color.primary'))
            .backgroundColor(Color.Transparent)
            .height(48)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.actionAccessibilityText($r('app.string.button_replace')))
            .onClick(() => {
              this.beginReplace();
            })

          if (this.revealed) {
            Button(getString($r('app.string.button_copy')))
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.primary'))
              .backgroundColor(Color.Transparent)
              .height(48)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText(this.actionAccessibilityText($r('app.string.button_copy')))
              .onClick(() => {
                this.copyValue();
              })
          }
        }
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .padding({ left: SPACING.sm })
        .backgroundColor($r('app.color.surface_subtle'))
        .borderRadius(RADIUS.md)
      }
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
