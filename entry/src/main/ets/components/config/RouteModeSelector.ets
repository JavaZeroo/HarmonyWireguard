import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import type { RouteModeType } from '../../model/WgConfig';
import { deriveRouteMode } from '../../common/Utils';

@Component
export struct RouteModeSelector {
  @Prop allowedIPs: string = '';
  @State mode: RouteModeType = 'global';
  @State customCidrs: string = '';

  onChange?: (allowedIPs: string) => void;

  aboutToAppear(): void {
    this.mode = deriveRouteMode(this.allowedIPs);
    if (this.mode === 'custom' || this.mode === 'lanOnly') {
      this.customCidrs = this.allowedIPs;
    }
  }

  private updateAllowedIPs(): void {
    let result = '';
    switch (this.mode) {
      case 'global':
        result = '0.0.0.0/0, ::/0';
        break;
      case 'lanOnly':
        result = this.customCidrs || '192.168.0.0/16, 10.0.0.0/8';
        break;
      case 'custom':
        result = this.customCidrs;
        break;
    }
    this.onChange?.(result);
  }

  @Builder
  ModeOption(value: RouteModeType, label: string, description: string) {
    Row() {
      Radio({ value: value, group: 'routeMode' })
        .checked(this.mode === value)
        .onChange((checked: boolean) => {
          if (checked) {
            this.mode = value;
            this.updateAllowedIPs();
          }
        })

      Column() {
        Text(label)
          .fontSize(TYPOGRAPHY.body_md.size)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text(description)
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: SPACING.sm })
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding(SPACING.sm)
    .accessibilityText(label + ', ' + description)
    .onClick(() => {
      this.mode = value;
      this.updateAllowedIPs();
    })
  }

  build() {
    Column() {
      Text(getString($r('app.string.field_allowed_ips')))
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      Column({ space: SPACING.xs }) {
        this.ModeOption('global',
          getString($r('app.string.route_global')),
          '0.0.0.0/0, ::/0')

        this.ModeOption('lanOnly',
          getString($r('app.string.route_lan_only')),
          '192.168.0.0/16, 10.0.0.0/8')

        this.ModeOption('custom',
          getString($r('app.string.route_custom')),
          getString($r('app.string.route_custom_description')))
      }
      .width('100%')
      .padding(SPACING.sm)
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(RADIUS.md)
      .margin({ bottom: SPACING.sm })

      if (this.mode === 'custom' || this.mode === 'lanOnly') {
        TextInput({ placeholder: getString($r('app.string.placeholder_custom_cidrs')), text: this.customCidrs })
          .fontSize(TYPOGRAPHY.body_md.size)
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.surface_subtle'))
          .borderRadius(RADIUS.md)
          .onChange((val) => {
            this.customCidrs = val;
            this.updateAllowedIPs();
          })
      }
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
