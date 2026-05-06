import { router } from '@kit.ArkUI';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { APP_CONSTANTS, COLORS } from '../common/Constants';

const TAG = 'StatusPage';

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

@Entry
@Component
struct StatusPage {
  @State status: string = '已连接';
  @State rxBytes: number = 0;
  @State txBytes: number = 0;

  async disconnect(): Promise<void> {
    try {
      const want: Want = {
        deviceId: '',
        bundleName: APP_CONSTANTS.BUNDLE_NAME,
        abilityName: APP_CONSTANTS.VPN_ABILITY_NAME
      };
      await vpnExtension.stopVpnExtensionAbility(want);
      this.status = '已断开';
    } catch (err) {
      this.status = '断开失败';
    }
  }

  build() {
    Column() {
      Text('连接状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24, bottom: 24 })

      Column() {
        Text(this.status)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.status === '已连接' ? COLORS.PRIMARY : COLORS.DANGER)
          .margin({ bottom: 24 })

        Row() {
          Column() {
            Text('接收')
              .fontSize(14)
              .fontColor(COLORS.TEXT_PRIMARY)
            Text(formatBytes(this.rxBytes))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)

          Column() {
            Text('发送')
              .fontSize(14)
              .fontColor(COLORS.TEXT_PRIMARY)
            Text(formatBytes(this.txBytes))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 32 })
      }
      .width('100%')
      .padding(24)
      .backgroundColor(COLORS.CARD)
      .borderRadius(12)
      .margin({ left: 16, right: 16 })

      Button('断开连接')
        .width('90%')
        .height(50)
        .fontSize(18)
        .backgroundColor(COLORS.DANGER)
        .margin({ top: 32 })
        .onClick(() => this.disconnect())

      Button('返回')
        .width('90%')
        .height(50)
        .fontSize(18)
        .backgroundColor(COLORS.SECONDARY)
        .margin({ top: 16 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.BACKGROUND)
  }
}
