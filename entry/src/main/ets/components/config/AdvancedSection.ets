import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';

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
      Text(getString($r('app.string.section_advanced')))
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      this.SwitchRow(getString($r('app.string.option_auto_connect')), this.autoConnect, (val) => this.onAutoConnectChange?.(val))
      this.SwitchRow(getString($r('app.string.option_reconnect')), this.reconnectOnNetworkChange, (val) => this.onReconnectChange?.(val))
      this.SwitchRow(getString($r('app.string.option_block_ipv6')), this.blockIpv6Leak, (val) => this.onBlockIpv6Change?.(val))
      this.SwitchRow(getString($r('app.string.option_allow_lan')), this.allowLanAccess, (val) => this.onAllowLanChange?.(val))
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
