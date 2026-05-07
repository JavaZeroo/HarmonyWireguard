import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';

@Component
export struct AdvancedSection {
  @Prop autoConnect: boolean = false;
  @Prop reconnectOnNetworkChange: boolean = false;
  @Prop blockIpv6Leak: boolean = false;
  @Prop allowLanAccess: boolean = false;

  onAutoConnectChange?: (val: boolean) => void;
  onReconnectChange?: (val: boolean) => void;
  onBlockIpv6Change?: (val: boolean) => void;
  onAllowLanChange?: (val: boolean) => void;

  @Builder
  SwitchRow(label: string, checked: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(TYPOGRAPHY.body_md.size)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor($r('app.color.primary'))
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
    .padding({ left: SPACING.sm, right: SPACING.sm })
    .backgroundColor($r('app.color.surface_subtle'))
    .borderRadius(RADIUS.md)
  }

  build() {
    Column({ space: SPACING.sm }) {
      Text(getContext().resourceManager.getStringSync($r('app.string.section_advanced').id))
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      this.SwitchRow('自动连接', this.autoConnect, (val) => this.onAutoConnectChange?.(val))
      this.SwitchRow('网络变化后重连', this.reconnectOnNetworkChange, (val) => this.onReconnectChange?.(val))
      this.SwitchRow('IPv6 防泄露', this.blockIpv6Leak, (val) => this.onBlockIpv6Change?.(val))
      this.SwitchRow('允许访问本地网络', this.allowLanAccess, (val) => this.onAllowLanChange?.(val))
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
