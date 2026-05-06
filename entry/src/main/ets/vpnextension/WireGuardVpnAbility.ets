import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { wantAgent, Want } from '@kit.AbilityKit';
import wgNative from 'libentry.so';
import { APP_CONSTANTS } from '../common/Constants';

const TAG = 'WireGuardVpnAbility';

interface VpnParamConfig {
  addresses: vpnExtension.LinkAddress[];
  dnsAddresses: string[];
  mtu: number;
  serverIp: string;
  serverPort: number;
  wgPrivateKey: string;
  wgPeerPublicKey: string;
  wgPresharedKey: string;
  wgKeepalive: number;
}

interface WgNativeConfig {
  privateKey: string;
  peerPublicKey: string;
  presharedKey: string;
  endpointIp: string;
  endpointPort: number;
  keepalive: number;
}

const DEFAULT_VPN_CONFIG = {
  ADDRESS: { address: { address: '10.0.0.2', family: 1 }, prefixLength: 24 },
  DNS: '8.8.8.8',
  MTU: 1420,
  KEEPALIVE: 25
} as const;

export default class WireGuardVpnAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | null = null;
  private tunFd: number = -1;

  async onCreate(want: Want): Promise<void> {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'WireGuardVpnAbility onCreate');
    this.vpnConnection = vpnExtension.createVpnConnection(this.context);

    try {
      const config = this.parseConfig(want);
      await this.startVpnConnection(config);
      await this.showForegroundNotification();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to start VPN: %{public}s', msg);
      this.destroyVpn();
      throw new Error(msg);
    }
  }

  private parseConfig(want: Want): VpnParamConfig {
    const configStr = want.parameters?.['config'] as string;
    if (!configStr) {
      throw new Error('VPN config not found in want parameters');
    }
    
    try {
      return JSON.parse(configStr) as VpnParamConfig;
    } catch {
      throw new Error('Invalid VPN config JSON');
    }
  }

  private async startVpnConnection(config: VpnParamConfig): Promise<void> {
    // 1. 建立 UDP socket
    const socketFd: number = wgNative.udpConnect(config.serverIp, config.serverPort);
    if (socketFd < 0) {
      throw new Error('Failed to create UDP socket');
    }
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'UDP socket created: %{public}d', socketFd);

    // 2. protect socket，避免流量回环
    await this.vpnConnection!.protect(socketFd);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'socket protected: %{public}d', socketFd);

    // 3. 构建 VpnConfig
    const vpnConfig: vpnExtension.VpnConfig = {
      addresses: config.addresses || [DEFAULT_VPN_CONFIG.ADDRESS],
      dnsAddresses: config.dnsAddresses || [DEFAULT_VPN_CONFIG.DNS],
      mtu: config.mtu || DEFAULT_VPN_CONFIG.MTU,
      isIPv4Accepted: true,
      isIPv6Accepted: false,
      isBlocking: false
    };

    // 4. 创建 VPN 连接，获取 TUN fd
    this.tunFd = await this.vpnConnection!.create(vpnConfig);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN created, tunFd: %{public}d', this.tunFd);

    // 5. 启动 Native 层 WireGuard + 数据转发
    const wgConfig: WgNativeConfig = {
      privateKey: config.wgPrivateKey || '',
      peerPublicKey: config.wgPeerPublicKey || '',
      presharedKey: config.wgPresharedKey || '',
      endpointIp: config.serverIp,
      endpointPort: config.serverPort,
      keepalive: config.wgKeepalive || DEFAULT_VPN_CONFIG.KEEPALIVE
    };
    
    const ret: number = wgNative.startVpn(this.tunFd, socketFd, wgConfig);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Native startVpn result: %{public}d', ret);
  }

  onDestroy(): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'WireGuardVpnAbility onDestroy');
    wgNative.stopVpn();
    this.destroyVpn();
  }

  private async showForegroundNotification(): Promise<void> {
    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{ 
          deviceId: '', 
          bundleName: APP_CONSTANTS.BUNDLE_NAME, 
          abilityName: 'EntryAbility' 
        }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Foreground notification prepared, agent=%{public}s', JSON.stringify(agent));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to show notification: %{public}s', msg);
    }
  }

  private destroyVpn(): void {
    if (this.vpnConnection) {
      this.vpnConnection.destroy().catch((err: Error) => {
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to destroy VPN: %{public}s', JSON.stringify(err));
      });
      this.vpnConnection = null;
    }
    this.tunFd = -1;
  }
}
