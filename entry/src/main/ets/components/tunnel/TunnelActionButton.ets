import { RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import type { TunnelStatusType } from '../../model/WgConfig';

@Component
export struct TunnelActionButton {
  @Prop status: TunnelStatusType = 'disconnected';
  @Prop tunnelName: string = '';

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

  private getAccessibilityText(): string {
    if (this.status === 'connected') {
      return getString($r('app.string.accessibility_disconnect_tunnel')).replace('%s', this.tunnelName);
    }
    if (this.status === 'connecting') {
      return this.getButtonText();
    }
    return getString($r('app.string.accessibility_connect_tunnel')).replace('%s', this.tunnelName);
  }

  build() {
    Button(this.getButtonText())
      .fontSize(TYPOGRAPHY.body_lg.size)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor(this.getButtonColor())
      .width('80%')
      .constraintSize({ minWidth: 160 })
      .height(50)
      .padding({ left: 32, right: 32 })
      .borderRadius(RADIUS.full)
      .accessibilityText(this.getAccessibilityText())
      .stateStyles({
        pressed: {
          .scale({ x: 0.97, y: 0.97 })
          .opacity(0.9)
        }
      })
      .onClick(() => {
        this.onPrimaryAction?.();
      })
  }
}
