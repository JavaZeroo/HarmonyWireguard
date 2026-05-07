import { RADIUS, SPACING, getString } from '../../common/DesignSystem';
import type { TunnelStatusType } from '../../model/WgConfig';

@Component
export struct StatusBadge {
  @Prop status: TunnelStatusType = 'disconnected';

  private getStatusText(): string {
    switch (this.status) {
      case 'connected':
        return getString($r('app.string.status_connected'));
      case 'connecting':
        return getString($r('app.string.status_connecting'));
      case 'failed':
        return getString($r('app.string.status_failed'));
      default:
        return getString($r('app.string.status_disconnected'));
    }
  }

  private getDotColor(): ResourceColor {
    switch (this.status) {
      case 'connected':
        return $r('app.color.success');
      case 'connecting':
        return $r('app.color.primary');
      case 'failed':
        return $r('app.color.danger');
      default:
        return $r('app.color.text_tertiary');
    }
  }

  private getTextColor(): ResourceColor {
    switch (this.status) {
      case 'connected':
        return $r('app.color.success');
      case 'connecting':
        return $r('app.color.primary');
      case 'failed':
        return $r('app.color.danger');
      default:
        return $r('app.color.text_secondary');
    }
  }

  build() {
    Row() {
      Circle()
        .width(8)
        .height(8)
        .fill(this.getDotColor())
        .margin({ right: SPACING.xs })

      Text(this.getStatusText())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getTextColor())
    }
    .padding({ left: SPACING.sm, right: SPACING.sm, top: 4, bottom: 4 })
    .backgroundColor(this.status === 'connected' ? $r('app.color.success_bg') :
      this.status === 'connecting' ? $r('app.color.primary_bg') :
        this.status === 'failed' ? $r('app.color.danger_bg') : $r('app.color.surface_subtle'))
    .borderRadius(RADIUS.full)
  }
}
