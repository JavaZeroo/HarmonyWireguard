import { ComponentContent, UIContext } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from './DesignSystem';

// 调用方传入的确认弹窗选项（interface → 允许对象字面量传参）。
export interface ConfirmOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  confirmColor?: ResourceColor;
  secure?: boolean;            // true = 顶部显示警示图标（敏感操作：查看私钥 / 删除配置）
  onConfirm?: () => void;
  onCancel?: () => void;
}

// 弹窗内部模型（含注入的 close 回调）。用 new + 逐字段赋值，规避 ArkTS 类字面量限制。
class DialogModel {
  title: string = '';
  message: string = '';
  confirmText: string = '';
  cancelText: string = '';
  confirmColor: ResourceColor = $r('app.color.danger');
  secure: boolean = false;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
  close: () => void = () => {};
}

// 顶层 @Builder：openCustomDialog 的内容须由 wrapBuilder 包裹的顶层函数提供（不能内联 lambda）。
@Builder
function confirmDialogContent(model: DialogModel) {
  Column() {
    if (model.secure) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(48)
        .fontColor([$r('app.color.warning')])
        .margin({ bottom: SPACING.md })
    }

    Text(model.title)
      .fontSize(TYPOGRAPHY.title_sm.size)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .textAlign(model.secure ? TextAlign.Center : TextAlign.Start)
      .margin({ bottom: SPACING.sm })

    if (model.message.length > 0) {
      Text(model.message)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(model.secure ? TextAlign.Center : TextAlign.Start)
        .margin({ bottom: SPACING.lg })
    }

    Row() {
      Button(model.cancelText.length > 0 ? model.cancelText : getString($r('app.string.button_cancel')))
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onClick(() => {
          model.onCancel();
          model.close();
        })

      Button(model.confirmText.length > 0 ? model.confirmText : getString($r('app.string.button_confirm')))
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor(model.confirmColor)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onClick(() => {
          model.onConfirm();
          model.close();
        })
    }
    .width('100%')
  }
  .width('85%')
  .constraintSize({ maxWidth: 400 })
  .padding(SPACING.lg)
  .backgroundColor($r('app.color.surface'))
  .borderRadius(RADIUS.xl)
}

// 统一弹窗封装：任意持有 UIContext 的组件/服务都可调用，无需各自维护 CustomDialogController。
export class DialogHelper {
  static showConfirm(ctx: UIContext, opts: ConfirmOptions): void {
    const model = new DialogModel();
    model.title = opts.title;
    model.message = opts.message;
    model.confirmText = opts.confirmText ?? '';
    model.cancelText = opts.cancelText ?? '';
    if (opts.confirmColor !== undefined) {
      model.confirmColor = opts.confirmColor;
    }
    model.secure = opts.secure ?? false;
    if (opts.onConfirm !== undefined) {
      model.onConfirm = opts.onConfirm;
    }
    if (opts.onCancel !== undefined) {
      model.onCancel = opts.onCancel;
    }

    let content: ComponentContent<DialogModel> | null = null;
    model.close = () => {
      if (content !== null) {
        ctx.getPromptAction().closeCustomDialog(content as ComponentContent<Object>);
      }
    };
    content = new ComponentContent(ctx, wrapBuilder(confirmDialogContent), model);
    ctx.getPromptAction().openCustomDialog(content as ComponentContent<Object>, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      isModal: true
    });
  }
}
