import { RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import type { TunnelStatusType } from '../../model/WgConfig';

@Component
export struct TunnelActionButton {
  @Prop status: TunnelStatusType = 'disconnected';

  onPrimaryAction?: () => void;

  private getButtonText(): string {
    switch (this.status) {
      case 'connected':
        return getString($r('app.string.button_disconnect'));
      case 'connecting':
        return getString($r('app.string.button_cancel'));
      case 'failed':
        return getString($r('app.string.button_retry'));
      default:
        return getString($r('app.string.button_connect'));
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
