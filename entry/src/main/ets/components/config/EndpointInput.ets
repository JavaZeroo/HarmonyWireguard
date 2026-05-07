import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { parseEndpoint } from '../../common/Utils';
import { validatePort } from '../../common/Validators';

@Component
export struct EndpointInput {
  @Prop endpoint: string = '';
  @State host: string = '';
  @State port: string = '';
  @State isIPv6: boolean = false;

  onChange?: (endpoint: string) => void;

  aboutToAppear(): void {
    this.syncFromEndpoint();
  }

  private syncFromEndpoint(): void {
    const parsed = parseEndpoint(this.endpoint);
    if (parsed) {
      this.host = parsed.host;
      this.port = String(parsed.port);
      this.isIPv6 = parsed.isIPv6;
    } else if (this.endpoint) {
      // Fallback: try simple split
      const parts = this.endpoint.split(':');
      if (parts.length >= 2) {
        this.host = parts.slice(0, -1).join(':');
        this.port = parts[parts.length - 1];
      }
    }
  }

  private updateEndpoint(): void {
    let ep = '';
    if (this.isIPv6 && this.host.length > 0) {
      ep = `[${this.host}]:${this.port}`;
    } else if (this.host.length > 0) {
      ep = `${this.host}:${this.port}`;
    }
    this.onChange?.(ep);
  }

  build() {
    Column() {
      Text(getContext().resourceManager.getStringSync($r('app.string.field_endpoint').id))
        .fontSize(TYPOGRAPHY.label.size)
        .fontWeight(TYPOGRAPHY.label.weight)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: SPACING.xs })
        .width('100%')

      Row({ space: SPACING.sm }) {
        TextInput({ placeholder: 'vpn.example.com', text: this.host })
          .fontSize(TYPOGRAPHY.body_md.size)
          .layoutWeight(3)
          .height(44)
          .backgroundColor($r('app.color.surface_subtle'))
          .borderRadius(RADIUS.md)
          .onChange((val) => {
            this.host = val;
            this.isIPv6 = val.includes(':');
            this.updateEndpoint();
          })

        TextInput({ placeholder: '51820', text: this.port })
          .fontSize(TYPOGRAPHY.body_md.size)
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.surface_subtle'))
          .borderRadius(RADIUS.md)
          .type(InputType.Number)
          .onChange((val) => {
            this.port = val;
            this.updateEndpoint();
          })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: SPACING.md })
  }
}
