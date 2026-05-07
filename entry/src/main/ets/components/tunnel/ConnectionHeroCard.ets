import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { formatBytes, formatHandshake } from '../../common/Formatters';
import type { TunnelStatusType } from '../../model/WgConfig';
import { TunnelActionButton } from './TunnelActionButton';

@Component
export struct ConnectionHeroCard {
  @Prop status: TunnelStatusType = 'disconnected';
  @Prop tunnelName: string = '';
  @Prop endpoint: string = '';
  @Prop lastHandshakeAt: number = -1; // timestamp in seconds
  @Prop rxBytes: number = 0;
  @Prop txBytes: number = 0;
  @Prop latestError: string = '';

  onPrimaryAction?: () => void;
  onDetail?: () => void;

  private getBackgroundColor(): ResourceColor {
    switch (this.status) {
      case 'connected':
        return $r('app.color.success_bg');
      case 'connecting':
        return $r('app.color.primary_bg');
      case 'failed':
        return $r('app.color.danger_bg');
      default:
        return $r('app.color.surface');
    }
  }

  private getStatusText(): string {
    const rm = getContext().resourceManager;
    switch (this.status) {
      case 'connected':
        return rm.getStringSync($r('app.string.status_connected').id);
      case 'connecting':
        return rm.getStringSync($r('app.string.status_connecting').id);
      case 'failed':
        return rm.getStringSync($r('app.string.status_failed').id);
      default:
        return rm.getStringSync($r('app.string.status_disconnected').id);
    }
  }

  private getStatusDotColor(): ResourceColor {
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

  private getHandshakeText(): string {
    if (this.lastHandshakeAt === undefined || this.lastHandshakeAt < 0) {
      return getContext().resourceManager.getStringSync($r('app.string.hint_handshake_never').id);
    }
    const now = Math.floor(Date.now() / 1000);
    const ago = now - this.lastHandshakeAt;
    return formatHandshake(ago);
  }

  build() {
    Column() {
      // Header: name + status
      Row() {
        Column() {
          Text(this.tunnelName || getContext().resourceManager.getStringSync($r('app.string.section_current_connection').id))
            .fontSize(TYPOGRAPHY.title_sm.size)
            .fontWeight(TYPOGRAPHY.title_sm.weight)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.getStatusDotColor())
              .margin({ right: SPACING.xs })

            Text(this.getStatusText())
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.text_secondary'))

            if (this.status === 'connected' || this.status === 'failed') {
              Text(' · ' + this.getHandshakeText())
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .margin({ top: SPACING.xs })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.status === 'connecting') {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.primary'))
        }
      }
      .width('100%')
      .margin({ bottom: SPACING.md })

      // Endpoint
      if (this.endpoint.length > 0) {
        Text(this.endpoint)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .margin({ bottom: SPACING.sm })
      }

      // Traffic
      if (this.status === 'connected' || this.rxBytes > 0 || this.txBytes > 0) {
        Row() {
          Column() {
            Text(getContext().resourceManager.getStringSync($r('app.string.traffic_rx').id))
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_secondary'))
            Text(formatBytes(this.rxBytes))
              .fontSize(TYPOGRAPHY.body_lg.size)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text(getContext().resourceManager.getStringSync($r('app.string.traffic_tx').id))
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor($r('app.color.text_secondary'))
            Text(formatBytes(this.txBytes))
              .fontSize(TYPOGRAPHY.body_lg.size)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .margin({ bottom: SPACING.md })
      }

      // Error
      if (this.status === 'failed' && this.latestError) {
        Text(this.latestError)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.danger'))
          .width('100%')
          .margin({ bottom: SPACING.md })
      }

      // Actions
      Row() {
        TunnelActionButton({
          status: this.status,
          onPrimaryAction: this.onPrimaryAction
        })

        if (this.status !== 'disconnected') {
          Button(getContext().resourceManager.getStringSync($r('app.string.button_detail').id))
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontColor($r('app.color.primary'))
            .backgroundColor('transparent')
            .height(40)
            .onClick(() => {
              this.onDetail?.();
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(SPACING.lg)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS.xl)
  }
}
