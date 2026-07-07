import { SPACING, RADIUS, TYPOGRAPHY, SHADOW, getString } from '../../common/DesignSystem';
import { deriveRouteMode, formatEndpointShort } from '../../common/Utils';
import type { WgConfig } from '../../model/WgConfig';
import type { TunnelStatusType } from '../../model/WgConfig';
import { StatusBadge } from '../common/StatusBadge';

@Reusable
@Component
export struct TunnelListItem {
  @Prop config: WgConfig;
  @Prop status: TunnelStatusType = 'disconnected';
  @Prop selected: boolean = false;

  onSelect?: () => void;
  onConnect?: () => void;
  onDisconnect?: () => void;

  private isLive(): boolean {
    return this.status === 'connected' || this.status === 'connecting';
  }

  private getIconBgColor(): ResourceColor {
    switch (this.status) {
      case 'connected':
        return $r('app.color.success_bg');
      case 'connecting':
        return $r('app.color.primary_bg');
      case 'failed':
        return $r('app.color.danger_bg');
      default:
        return $r('app.color.surface_subtle');
    }
  }

  private getIconColor(): ResourceColor {
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

  private getRouteLabel(): string {
    const mode = deriveRouteMode(this.config.allowedIPs);
    switch (mode) {
      case 'global':
        return getString($r('app.string.route_global'));
      case 'lanOnly':
        return getString($r('app.string.route_lan_only'));
      default:
        return getString($r('app.string.route_custom'));
    }
  }

  private getKeepaliveLabel(): string {
    if (this.config.persistentKeepalive > 0) {
      return 'Keepalive ' + this.config.persistentKeepalive + 's';
    }
    return '';
  }

  build() {
    Row({ space: SPACING.md }) {
      // 状态色图标容器
      Stack() {
        SymbolGlyph($r('sys.symbol.wifi'))
          .fontSize(22)
          .fontColor([this.getIconColor()])
      }
      .width(44)
      .height(44)
      .backgroundColor(this.getIconBgColor())
      .borderRadius(RADIUS.md)

      Column() {
        Row() {
          Text(this.config.name)
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          StatusBadge({ status: this.status })
        }
        .width('100%')

        Text(formatEndpointShort(this.config.endpoint))
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: SPACING.xxs })

        Row() {
          Text(this.getRouteLabel())
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_tertiary'))

          if (this.getKeepaliveLabel().length > 0) {
            Text(' · ' + this.getKeepaliveLabel())
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
        .margin({ top: SPACING.xxs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isLive() })
        .selectedColor($r('app.color.primary'))
        .onChange((isOn: boolean) => {
          if (isOn) {
            this.onConnect?.();
          } else {
            this.onDisconnect?.();
          }
        })
    }
    .width('100%')
    .padding(SPACING.md)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.lg)
    .border(this.isLive()
      ? { width: 1, color: this.getIconColor() }
      : { width: 1, color: Color.Transparent })
    .shadow({
      radius: SHADOW.sm.radius,
      color: SHADOW.sm.color,
      offsetX: SHADOW.sm.offsetX,
      offsetY: SHADOW.sm.offsetY
    })
    .hoverEffect(HoverEffect.Scale)
    .onClick(() => {
      this.onSelect?.();
    })
    .stateStyles({
      pressed: {
        .scale({ x: 0.98, y: 0.98 })
        .opacity(0.92)
      }
    })
  }
}
