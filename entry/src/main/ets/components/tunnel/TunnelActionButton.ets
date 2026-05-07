import { RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import type { TunnelStatusType } from '../../model/WgConfig';

@Component
export struct TunnelActionButton {
  @Prop status: TunnelStatusType = 'disconnected';

  onPrimaryAction?: () => void;

  private getButtonText(): string {
    const rm = getContext().resourceManager;
    switch (this.status) {
      case 'connected':
        return rm.getStringSync($r('app.string.button_disconnect').id);
      case 'connecting':
        return rm.getStringSync($r('app.string.button_cancel').id);
      case 'failed':
        return rm.getStringSync($r('app.string.button_retry').id);
      default:
        return rm.getStringSync($r('app.string.button_connect').id);
    }
  }

  private getButtonColor(): ResourceColor {
    switch (this.status) {
      case 'connected':
        return $r('app.color.danger');
      case 'failed':
        return $r('app.color.primary');
      default:
        return $r('app.color.primary');
    }
  }

  build() {
    Button(this.getButtonText())
      .fontSize(TYPOGRAPHY.body_md.size)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor(this.getButtonColor())
      .height(44)
      .padding({ left: 32, right: 32 })
      .borderRadius(RADIUS.md)
      .onClick(() => {
        this.onPrimaryAction?.();
      })
  }
}
