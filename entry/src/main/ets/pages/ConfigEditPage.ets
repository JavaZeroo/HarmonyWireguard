import { router } from '@kit.ArkUI';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';

@Entry
@Component
struct ConfigEditPage {
  @State config: WgConfig = {
    id: '',
    name: '',
    privateKey: '',
    address: '10.0.0.2/24',
    dns: '8.8.8.8',
    mtu: 1420,
    peerPublicKey: '',
    presharedKey: '',
    allowedIPs: '0.0.0.0/0, ::/0',
    endpoint: '',
    persistentKeepalive: 25
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['id']) {
      const exist = configManager.getConfigById(params['id']);
      if (exist) {
        this.config = {
          id: exist.id,
          name: exist.name,
          privateKey: exist.privateKey,
          address: exist.address,
          dns: exist.dns,
          mtu: exist.mtu,
          peerPublicKey: exist.peerPublicKey,
          presharedKey: exist.presharedKey,
          allowedIPs: exist.allowedIPs,
          endpoint: exist.endpoint,
          persistentKeepalive: exist.persistentKeepalive
        };
      }
    } else {
      this.config.id = Date.now().toString();
    }
  }

  saveConfig(): void {
    if (!this.config.name || !this.config.privateKey || !this.config.peerPublicKey || !this.config.endpoint) {
      return;
    }
    configManager.saveConfig(this.config);
    router.back();
  }

  deleteConfig(): void {
    if (this.config.id) {
      configManager.deleteConfig(this.config.id);
      router.back();
    }
  }

  @Builder
  FormItem(label: string, placeholder: string, value: string, onChange: (val: string) => void) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor('#666')
        .margin({ bottom: 4 })
      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(44)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      Text(this.config.id ? '编辑配置' : '新建配置')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Scroll() {
        Column() {
          this.FormItem('配置名称', '例如: 公司内网', this.config.name, (v) => this.config.name = v)
          this.FormItem('私钥 (PrivateKey)', 'Base64 编码的 32 字节私钥', this.config.privateKey, (v) => this.config.privateKey = v)
          this.FormItem('地址 (Address)', '例如: 10.0.0.2/24', this.config.address, (v) => this.config.address = v)
          this.FormItem('DNS', '例如: 8.8.8.8, 1.1.1.1', this.config.dns, (v) => this.config.dns = v)
          this.FormItem('MTU', '默认 1420', this.config.mtu.toString(), (v) => this.config.mtu = parseInt(v) || 1420)
          this.FormItem('对端公钥 (PublicKey)', '服务器公钥', this.config.peerPublicKey, (v) => this.config.peerPublicKey = v)
          this.FormItem('PresharedKey', '可选预共享密钥', this.config.presharedKey, (v) => this.config.presharedKey = v)
          this.FormItem('AllowedIPs', '例如: 0.0.0.0/0, ::/0', this.config.allowedIPs, (v) => this.config.allowedIPs = v)
          this.FormItem('Endpoint', '例如: vpn.example.com:51820', this.config.endpoint, (v) => this.config.endpoint = v)
          this.FormItem('PersistentKeepalive', '保活间隔秒数，默认 25', this.config.persistentKeepalive.toString(), (v) => this.config.persistentKeepalive = parseInt(v) || 25)

          Row() {
            Button('取消')
              .width(this.config.id ? '30%' : '45%')
              .backgroundColor('#999')
              .onClick(() => router.back())

            if (this.config.id) {
              Button('删除')
                .width('30%')
                .backgroundColor('#FF4444')
                .onClick(() => this.deleteConfig())
            }

            Button('保存')
              .width(this.config.id ? '30%' : '45%')
              .onClick(() => this.saveConfig())
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 24 })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
