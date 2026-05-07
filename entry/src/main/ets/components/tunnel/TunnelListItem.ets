import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { deriveRouteMode, formatEndpointShort } from '../../common/Utils';
import type { WgConfig } from '../../model/WgConfig';
import type { TunnelStatusType } from '../../model/WgConfig';
import { TunnelStatusBadge } from './TunnelStatusBadge';

@Component
export struct TunnelListItem {
  @Prop config: WgConfig;
  @Prop status: TunnelStatusType = 'disconnected';
  @Prop selected: boolean = false;

  onSelect?: () => void;
  onConnect?: () => void;
  onDisconnect?: () => void;

  private getRouteLabel(): string {
    const mode = deriveRouteMode(this.config.allowedIPs);
    const rm = getContext().resourceManager;
    switch (mode) {
      case 'global':
        return rm.getStringSync($r('app.string.route_global').id);
      case 'lanOnly':
        return rm.getStringSync($r('app.string.route_lan_only').id);
      default:
        return rm.getStringSync($r('app.string.route_custom').id);
    }
  }

  private getKeepaliveLabel(): string {
    if (this.config.persistentKeepalive > 0) {
      return 'Keepalive ' + this.config.persistentKeepalive + 's';
    }
    return '';
  }

  build() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.wifi'))
          .fontSize(24)
          .fontColor([$r('app.color.primary')])
          .margin({ right: SPACING.md })
      }
      .justifyContent(FlexAlign.Center)

      Column() {
        Row() {
          Text(this.config.name)
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          TunnelStatusBadge({ status: this.status })
        }
        .width('100%')
        .margin({ bottom: SPACING.xs })

        Text(formatEndpointShort(this.config.endpoint))
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: SPACING.xs })

        Row() {
          Text(this.getRouteLabel())
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_tertiary'))

          if (this.getKeepaliveLabel().length > 0) {
            Text(' · ')
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_tertiary'))

            Text(this.getKeepaliveLabel())
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.status === 'connected' || this.status === 'connecting' })
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
    .backgroundColor(this.selected ? $r('app.color.primary_bg') : $r('app.color.surface'))
    .borderRadius(RADIUS.lg)
    .onClick(() => {
      this.onSelect?.();
    })
    .stateStyles({
      pressed: {
        .scale({ x: 0.98, y: 0.98 })
      }
    })
  }
}
