import { SPACING, RADIUS, TYPOGRAPHY, SHADOW, getString } from '../../common/DesignSystem';
import { formatBytes } from '../../common/Formatters';
import type { TunnelStatusType } from '../../model/WgConfig';
import { TunnelActionButton } from './TunnelActionButton';

@Component
export struct ConnectionHeroCard {
  @Prop @Watch('onStatusChange') status: TunnelStatusType = 'disconnected';
  @Prop tunnelName: string = '';
  @Prop endpoint: string = '';
  @Prop lastHandshakeAt: number = -1; // timestamp in seconds
  @Prop rxBytes: number = 0;
  @Prop txBytes: number = 0;
  @Prop latestError: string = '';

  onPrimaryAction?: () => void;
  onDetail?: () => void;

  // 状态切换时给状态徽标一个"生长"动画，连接那一刻更有存在感
  @State private emblemScale: number = 1;
  // 雷达脉冲：已连接/连接中时徽标外圈一圈圈扩散淡出，营造"在线/活着"的感知
  @State private pulseScale: number = 0.95;
  @State private pulseOpacity: number = 0.4;
  private pulseStarted: boolean = false;

  aboutToAppear(): void {
    this.startPulseLoop();
  }

  private startPulseLoop(): void {
    if (this.pulseStarted) {
      return;
    }
    this.pulseStarted = true;
    this.pulseScale = 0.95;
    this.pulseOpacity = 0.4;
    // 无限循环：0.95→1.6 扩散、0.4→0 淡出。脉冲圆仅在 live 状态渲染，其余时静默。
    try {
      this.getUIContext().animateTo({
        duration: 1900, curve: Curve.EaseOut, iterations: -1, playMode: PlayMode.Normal
      }, () => {
        this.pulseScale = 1.6;
        this.pulseOpacity = 0;
      });
    } catch (e) {
      this.pulseOpacity = 0;
    }
  }

  onStatusChange(): void {
    this.emblemScale = 0.84;
    this.getUIContext().animateTo({ duration: 420, curve: Curve.Friction }, () => {
      this.emblemScale = 1;
    });
  }

  private isLive(): boolean {
    return this.status === 'connected' || this.status === 'connecting';
  }

  private getStatusColor(): ResourceColor {
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

  private getRingBgColor(): ResourceColor {
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

  private getStatusIcon(): Resource {
    switch (this.status) {
      case 'connected':
        return $r('sys.symbol.checkmark_circle');
      case 'failed':
        return $r('sys.symbol.exclamationmark_triangle');
      default:
        return $r('sys.symbol.wifi');
    }
  }

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

  private getStatusTextColor(): ResourceColor {
    return this.status === 'disconnected' ? $r('app.color.text_primary') : this.getStatusColor();
  }

  private getHandshakeText(): string {
    if (this.lastHandshakeAt === undefined || this.lastHandshakeAt < 0) {
      return getString($r('app.string.hint_handshake_never'));
    }
    const now = Math.floor(Date.now() / 1000);
    const ago = now - this.lastHandshakeAt;
    if (ago < 60) {
      return getString($r('app.string.hint_handshake_ago')).replace('%s', String(ago));
    }
    return getString($r('app.string.hint_handshake_min_ago')).replace('%s', String(Math.floor(ago / 60)));
  }

  @Builder
  StatusEmblem() {
    Stack() {
      // 雷达脉冲圈（仅 live 状态）
      if (this.isLive()) {
        Circle()
          .width(128)
          .height(128)
          .fill(this.getStatusColor())
          .opacity(this.pulseOpacity)
          .scale({ x: this.pulseScale, y: this.pulseScale })
      }

      // 底盘：状态色浅底圆
      Circle()
        .width(128)
        .height(128)
        .fill(this.getRingBgColor())

      if (this.status === 'connecting') {
        LoadingProgress()
          .width(56)
          .height(56)
          .color($r('app.color.primary'))
      } else {
        SymbolGlyph(this.getStatusIcon())
          .fontSize(60)
          .fontColor([this.getStatusColor()])
      }
    }
    .width(128)
    .height(128)
    // 已连接时给一圈柔和辉光，强化"安全在线"的感知
    .shadow(this.status === 'connected'
      ? { radius: 36, color: 'rgba(0,179,134,0.35)', offsetX: 0, offsetY: 0 }
      : { radius: 0, color: 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
    .scale({ x: this.emblemScale, y: this.emblemScale })
    .onClick(() => {
      this.onPrimaryAction?.();
    })
  }

  build() {
    Column() {
      // 顶部状态徽标
      this.StatusEmblem()

      // 大状态文字
      Text(this.getStatusText())
        .fontSize(TYPOGRAPHY.title_md.size)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getStatusTextColor())
        .margin({ top: SPACING.md })

      // 隧道名 · 握手时间
      Row() {
        Text(this.tunnelName || getString($r('app.string.section_current_connection')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.status === 'connected' || this.status === 'failed') {
          Text(' · ' + this.getHandshakeText())
            .fontSize(TYPOGRAPHY.body_sm.size)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .margin({ top: SPACING.xxs })

      // Endpoint
      if (this.endpoint.length > 0) {
        Text(this.endpoint)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: SPACING.xs })
      }

      // 错误提示
      if (this.status === 'failed' && this.latestError) {
        Text(this.latestError)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.danger'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .margin({ top: SPACING.sm })
          .padding({ left: SPACING.md, right: SPACING.md })
      }

      // 流量（已连接或有流量时）
      if (this.status === 'connected' || this.rxBytes > 0 || this.txBytes > 0) {
        Row() {
          this.TrafficStat($r('app.string.traffic_rx'), this.rxBytes, '↓')
          Divider()
            .vertical(true)
            .height(28)
            .color($r('app.color.divider'))
          this.TrafficStat($r('app.string.traffic_tx'), this.txBytes, '↑')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .margin({ top: SPACING.lg })
        .padding({ top: SPACING.md, bottom: SPACING.md })
        .borderRadius(RADIUS.lg)
        .backgroundColor($r('app.color.surface_subtle'))
      }

      // 主操作按钮
      TunnelActionButton({
        status: this.status,
        onPrimaryAction: this.onPrimaryAction
      })
        .margin({ top: SPACING.lg })

      // 详情入口
      if (this.status !== 'disconnected') {
        Button(getString($r('app.string.button_detail')))
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent)
          .height(36)
          .margin({ top: SPACING.xs })
          .onClick(() => {
            this.onDetail?.();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: SPACING.xl, bottom: SPACING.lg, left: SPACING.lg, right: SPACING.lg })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.xl)
    .shadow({
      radius: SHADOW.md.radius,
      color: SHADOW.md.color,
      offsetX: SHADOW.md.offsetX,
      offsetY: SHADOW.md.offsetY
    })
  }

  @Builder
  TrafficStat(label: Resource, value: number, arrow: string) {
    Column() {
      Row() {
        Text(arrow)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_tertiary'))
        Text(label)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: SPACING.xxs })
      }
      Text(formatBytes(value))
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: SPACING.xxs })
    }
    .layoutWeight(1)
  }
}
