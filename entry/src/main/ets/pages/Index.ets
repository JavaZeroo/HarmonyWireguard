import { vpnExtension } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { configManager } from '../service/ConfigManager';
import type { WgConfig } from '../model/WgConfig';
import { APP_CONSTANTS, COLORS, DEFAULT_CONFIG } from '../common/Constants';

const TAG = 'IndexPage';

interface VpnParamAddress {
  address: { address: string; family: number };
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

function parseAddress(address: string): VpnParamAddress {
  const [ip, prefix] = address.split('/');
  return {
    address: { address: ip, family: 1 },
    prefixLength: parseInt(prefix || '24')
  };
}

function parseEndpoint(endpoint: string): { serverIp: string; serverPort: number } {
  const [ip, port] = endpoint.split(':');
  return {
    serverIp: ip,
    serverPort: parseInt(port || String(DEFAULT_CONFIG.PORT))
  };
}

function buildVpnParamConfig(config: WgConfig): VpnParamConfig {
  const { serverIp, serverPort } = parseEndpoint(config.endpoint);
  
  return {
    addresses: [parseAddress(config.address)],
    dnsAddresses: config.dns ? config.dns.split(',') : [DEFAULT_CONFIG.DNS],
    mtu: config.mtu || DEFAULT_CONFIG.MTU,
    serverIp,
    serverPort,
    wgPrivateKey: config.privateKey,
    wgPeerPublicKey: config.peerPublicKey,
    wgPresharedKey: config.presharedKey,
    wgKeepalive: config.persistentKeepalive || DEFAULT_CONFIG.KEEPALIVE
  };
}

function createWant(config: WgConfig): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME,
    parameters: { config: JSON.stringify(buildVpnParamConfig(config)) }
  };
}

function createStopWant(): Want {
  return {
    deviceId: '',
    bundleName: APP_CONSTANTS.BUNDLE_NAME,
    abilityName: APP_CONSTANTS.VPN_ABILITY_NAME
  };
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
        const want = createWant(config);
        await vpnExtension.startVpnExtensionAbility(want);
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN started for %{public}s', config.name);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to start VPN: %{public}s', msg);
      }
      this.connectingId = '';
    } else {
      try {
        await vpnExtension.stopVpnExtensionAbility(createStopWant());
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN stopped');
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to stop VPN: %{public}s', msg);
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
          .fontColor(COLORS.TEXT_PRIMARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: false })
        .selectedColor(COLORS.PRIMARY)
        .onChange((isOn: boolean) => {
          this.toggleVpn(config, isOn);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLORS.CARD)
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
          .fontColor(COLORS.SECONDARY)
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
    .backgroundColor(COLORS.BACKGROUND)
  }
}
