import { SPACING, RADIUS, TYPOGRAPHY, SHADOW, getString } from '../../common/DesignSystem';
import { deriveRouteMode, formatEndpointShort } from '../../common/Utils';
import type { TunnelStatusType } from '../../model/WgConfig';
import { StatusBadge } from '../common/StatusBadge';

@Component
export struct TunnelListItem {
  // Keep secrets out of a frequently rebuilt @Prop object. The row only needs
  // these presentation fields from the full WireGuard configuration.
  @Prop name: string = '';
  @Prop endpoint: string = '';
  @Prop allowedIPs: string = '';
  @Prop persistentKeepalive: number = 0;
  @Prop status: TunnelStatusType = 'disconnected';
  @Prop selected: boolean = false;
  @Prop compact: boolean = false;
  // 一镜到底共享元素 id（手机端点开详情时非空；平板分栏为空）
  @Prop sharedTag: string = '';

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
    const mode = deriveRouteMode(this.allowedIPs);
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
    if (this.persistentKeepalive > 0) {
      return getString($r('app.string.label_keepalive_seconds'))
        .replace('%d', String(this.persistentKeepalive));
    }
    return '';
  }

  private getStatusLabel(): string {
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

  private getAccessibilityText(): string {
    return getString($r('app.string.accessibility_tunnel_summary'))
      .replace('%1$s', this.name)
      .replace('%2$s', this.getStatusLabel())
      .replace('%3$s', this.getRouteLabel());
  }

  private getToggleAccessibilityText(): string {
    const resource = this.isLive()
      ? $r('app.string.accessibility_disconnect_tunnel')
      : $r('app.string.accessibility_connect_tunnel');
    return getString(resource).replace('%s', this.name);
  }

  build() {
    Row({ space: this.compact ? SPACING.sm : SPACING.md }) {
      Row({ space: this.compact ? SPACING.sm : SPACING.md }) {
        // 状态色图标容器
        Stack() {
          SymbolGlyph($r('sys.symbol.wifi'))
            .fontSize(22)
            .fontColor([this.getIconColor()])
            // 状态色切换时图标颜色渐变
            .animation({ duration: 250, curve: Curve.EaseInOut })
        }
        .width(this.compact ? 40 : 44)
        .height(this.compact ? 40 : 44)
        .backgroundColor(this.getIconBgColor())
        .borderRadius(RADIUS.md)
        // 状态色切换时图标底色渐变
        .animation({ duration: 250, curve: Curve.EaseInOut })

        Column() {
          Row() {
            Text(this.name)
              .fontSize(TYPOGRAPHY.body_md.size)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            StatusBadge({ status: this.status })
          }
          .width('100%')

          Text(formatEndpointShort(this.endpoint))
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
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 48 })
      .borderRadius(RADIUS.md)
      .hoverEffect(HoverEffect.Highlight)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.getAccessibilityText())
      .accessibilityDescription(this.selected
        ? getString($r('app.string.accessibility_selected')) : '')
      .onClick(() => {
        this.onSelect?.();
      })
      .stateStyles({
        pressed: {
          .opacity(0.9)
        }
      })

      Toggle({ type: ToggleType.Switch, isOn: this.isLive() })
        .selectedColor($r('app.color.primary'))
        .accessibilityText(this.getToggleAccessibilityText())
        .onChange((isOn: boolean) => {
          // 防抖：仅当开关目标态与当前运行态真正不一致时才触发，
          // 避免重渲染/状态同步导致的伪 onChange 造成“连上又立刻断开”。
          if (isOn === this.isLive()) {
            return;
          }
          if (isOn) {
            this.onConnect?.();
          } else {
            this.onDisconnect?.();
          }
        })
    }
    .width('100%')
    .padding(this.compact ? SPACING.sm : SPACING.md)
    .backgroundColor(this.selected ? $r('app.color.primary_bg') : $r('app.color.surface'))
    .borderRadius(RADIUS.lg)
    .border(this.isLive()
      ? { width: 1, color: this.getIconColor() }
      : this.selected
        ? { width: 1, color: $r('app.color.primary') }
        : { width: 1, color: Color.Transparent })
    // 连接态描边颜色渐显/渐隐，而非突变
    .animation({ duration: 250, curve: Curve.EaseInOut })
    .shadow({
      radius: SHADOW.sm.radius,
      color: SHADOW.sm.color,
      offsetX: SHADOW.sm.offsetX,
      offsetY: SHADOW.sm.offsetY
    })
    // 一镜到底：点开详情时整卡片原地放大展开为全屏详情
    .geometryTransition(this.sharedTag)
  }
}
