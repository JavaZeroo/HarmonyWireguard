import { vpnExtension } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';

const DOMAIN = 0x0000;
const TAG = 'IndexPage';

interface VpnParamNetAddress {
  address: string;
  family: number;
}

interface VpnParamAddress {
  address: VpnParamNetAddress;
  prefixLength: number;
}

interface VpnParamConfig {
  addresses: VpnParamAddress[];
  dnsAddresses: string[];
  mtu: number;
  serverIp: string;
  serverPort: number;
  wgPrivateKey: string;
  wgPeerPublicKey: string;
  wgPresharedKey: string;
  wgKeepalive: number;
}

@Entry
@Component
struct Index {
  @State configs: WgConfig[] = [];
  @State connectingId: string = '';
  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    configManager.init(this.context);
    this.loadConfigs();
  }

  loadConfigs(): void {
    this.configs = configManager.getAllConfigs();
  }

  async toggleVpn(config: WgConfig, enable: boolean): Promise<void> {
    if (enable) {
      this.connectingId = config.id;
      try {
        const addr: VpnParamAddress = {
          address: { address: config.address.split('/')[0], family: 1 },
          prefixLength: parseInt(config.address.split('/')[1] || '24')
        };
        const paramConfig: VpnParamConfig = {
          addresses: [addr],
          dnsAddresses: config.dns ? config.dns.split(',') : ['8.8.8.8'],
          mtu: config.mtu || 1420,
          serverIp: config.endpoint.split(':')[0],
          serverPort: parseInt(config.endpoint.split(':')[1] || '51820'),
          wgPrivateKey: config.privateKey,
          wgPeerPublicKey: config.peerPublicKey,
          wgPresharedKey: config.presharedKey,
          wgKeepalive: config.persistentKeepalive
        };
        const want: Want = {
          deviceId: '',
          bundleName: 'com.example.harmonywireguard',
          abilityName: 'WireGuardVpnAbility',
          parameters: { config: JSON.stringify(paramConfig) }
        };
        await vpnExtension.startVpnExtensionAbility(want);
        hilog.info(DOMAIN, TAG, 'VPN started for %{public}s', config.name);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(DOMAIN, TAG, 'Failed to start VPN: %{public}s', msg);
      }
      this.connectingId = '';
    } else {
      try {
        const want: Want = {
          deviceId: '',
          bundleName: 'com.example.harmonywireguard',
          abilityName: 'WireGuardVpnAbility'
        };
        await vpnExtension.stopVpnExtensionAbility(want);
        hilog.info(DOMAIN, TAG, 'VPN stopped');
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(DOMAIN, TAG, 'Failed to stop VPN: %{public}s', msg);
      }
    }
  }

  @Builder
  ConfigItem(config: WgConfig) {
    Row() {
      Column() {
        Text(config.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Text(config.endpoint)
          .fontSize(14)
          .fontColor('#666')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: false })
        .selectedColor('#00AA00')
        .onChange((isOn: boolean) => {
          this.toggleVpn(config, isOn);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(8)
    .margin({ top: 8, bottom: 8 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/ConfigEditPage', params: { id: config.id } });
    })
  }

  build() {
    Column() {
      Text('WireGuard')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24, bottom: 16 })

      if (this.configs.length === 0) {
        Text('暂无配置，请点击下方添加')
          .fontSize(16)
          .fontColor('#999')
          .margin({ top: 100 })
      } else {
        List() {
          ForEach(this.configs, (config: WgConfig) => {
            ListItem() {
              this.ConfigItem(config)
            }
          }, (config: WgConfig) => config.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }

      Button('连接状态')
        .width('90%')
        .height(44)
        .fontSize(16)
        .margin({ bottom: 8 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/StatusPage' });
        })

      Button('添加配置')
        .width('90%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 24 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/ConfigEditPage' });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
