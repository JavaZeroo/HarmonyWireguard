import { router } from '@kit.ArkUI';
import { vpnExtension } from '@kit.NetworkKit';
import { common, Want } from '@kit.AbilityKit';

@Entry
@Component
struct StatusPage {
  @State status: string = '已连接';
  @State rxBytes: string = '0 B';
  @State txBytes: string = '0 B';
  private context = getContext(this) as common.UIAbilityContext;

  async disconnect(): Promise<void> {
    try {
      const want: Want = {
        deviceId: '',
        bundleName: 'com.example.harmonywireguard',
        abilityName: 'WireGuardVpnAbility'
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
          .fontColor(this.status === '已连接' ? '#00AA00' : '#FF4444')
          .margin({ bottom: 24 })

        Row() {
          Column() {
            Text('接收')
              .fontSize(14)
              .fontColor('#666')
            Text(this.rxBytes)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)

          Column() {
            Text('发送')
              .fontSize(14)
              .fontColor('#666')
            Text(this.txBytes)
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
      .backgroundColor('#fff')
      .borderRadius(12)
      .margin({ left: 16, right: 16 })

      Button('断开连接')
        .width('90%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#FF4444')
        .margin({ top: 32 })
        .onClick(() => this.disconnect())

      Button('返回')
        .width('90%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#999')
        .margin({ top: 16 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
