import { vpnExtension, VpnExtensionAbility, connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { wantAgent, Want } from '@kit.AbilityKit';
import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import wgNative from 'libentry.so';
import { APP_CONSTANTS } from '../common/Constants';
import type { WgConfig } from '../model/WgConfig';
import { buildVpnConfig, parseEndpoint } from '../common/VpnConfigBuilder';
import { configManager } from '../service/ConfigManager';

const IPV4_PATTERN = /^\d+\.\d+\.\d+\.\d+$/;

async function resolveHostToIPv4(host: string): Promise<string> {
  if (IPV4_PATTERN.test(host)) {
    return host;
  }
  const addresses = await connection.getAddressesByName(host);
  if (!addresses || addresses.length === 0) {
    throw new Error('DNS returned no records for ' + host);
  }
  for (const a of addresses) {
    if (a.address && !a.address.includes(':')) {
      return a.address;
    }
  }
  throw new Error('No IPv4 record for ' + host);
}

const TAG = 'WireGuardVpnAbility';

interface WgNativeConfig {
  privateKey: string;
  peerPublicKey: string;
  presharedKey: string;
  endpointIp: string;
  endpointPort: number;
  keepalive: number;
}

export default class WireGuardVpnAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | null = null;
  private tunFd: number = -1;
  private udpFd: number = -1;
  private activeConfigId: string = '';
  private statusTimer: number = -1;

  onCreate(want: Want): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'WireGuardVpnAbility onCreate entry');
    super.onCreate(want);
    if (this.context) {
      this.vpnConnection = vpnExtension.createVpnConnection(this.context);
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VpnConnection created');
    } else {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Context is invalid in onCreate');
      return;
    }

    this.loadConfigAndStart(want);
  }

  // 系统 VPN 授权对话框会用空 want 二次拉起本 extension，want.parameters 全丢
  // 所以走 prefs 兜底：UI 调 startVpnExtensionAbility 之前已经写入了 active config id
  private loadConfigAndStart(want: Want): void {
    let wgConfig: WgConfig | undefined;

    // 路径 A：want.parameters 里有 wgConfig JSON（直接调用、未经对话框时）
    try {
      const fromWant = this.parseConfig(want);
      if (fromWant) {
        wgConfig = fromWant;
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Loaded config from want.parameters');
      }
    } catch (err) {
      hilog.info(APP_CONSTANTS.DOMAIN, TAG,
        'want.parameters has no wgConfig, fallback to prefs');
    }

    // 路径 B：从 prefs 读 active config id
    if (!wgConfig) {
      try {
        configManager.init(this.context);
        wgConfig = configManager.getActiveConfig();
        if (wgConfig) {
          hilog.info(APP_CONSTANTS.DOMAIN, TAG,
            'Loaded config from prefs: id=%{public}s', wgConfig.id);
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'prefs load failed: %{public}s', msg);
      }
    }

    if (!wgConfig) {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'No config found in want or prefs');
      this.destroyVpn();
      return;
    }

    this.activeConfigId = wgConfig.id;

    this.startVpnConnection(wgConfig).then(() => {
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'startVpnConnection success');
      this.startStatusBroadcast();
      return this.showForegroundNotification();
    }).catch((err: Error) => {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to start VPN: %{public}s',
        err?.message ?? JSON.stringify(err) ?? '');
      this.publishDisconnected('failed');
      this.destroyVpn();
    });
  }

  private parseConfig(want: Want): WgConfig {
    const configStr = want.parameters?.['wgConfig'] as string;
    if (!configStr) {
      throw new Error('VPN config not found in want.parameters.wgConfig');
    }
    try {
      return JSON.parse(configStr) as WgConfig;
    } catch {
      throw new Error('Invalid VPN config JSON');
    }
  }

  private async startVpnConnection(wg: WgConfig): Promise<void> {
    const endpoint = parseEndpoint(wg.endpoint);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG,
      'Starting VPN endpoint=%{public}s:%{public}d', endpoint.serverIp, endpoint.serverPort);

    // 0. 主机名解析为 IPv4 —— native 层 inet_addr 只认点分十进制
    let resolvedIp: string;
    try {
      resolvedIp = await resolveHostToIPv4(endpoint.serverIp);
      if (resolvedIp !== endpoint.serverIp) {
        hilog.info(APP_CONSTANTS.DOMAIN, TAG,
          'Resolved %{public}s -> %{public}s', endpoint.serverIp, resolvedIp);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      throw new Error('DNS resolution failed: ' + msg);
    }

    // 1. 建立 UDP socket
    const socketFd: number = wgNative.udpConnect(resolvedIp, endpoint.serverPort);
    if (socketFd < 0) {
      throw new Error('Failed to create UDP socket');
    }
    this.udpFd = socketFd;
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'UDP socket created: %{public}d', socketFd);

    // 2. protect socket，避免流量回环
    await this.vpnConnection!.protect(socketFd);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'socket protected: %{public}d', socketFd);

    // 3. 构建 VpnConfig —— 不带 routes 字段，让系统按默认策略
    const vpnConfig = buildVpnConfig(wg);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG,
      'VpnConfig built: addresses=%{public}d, routes=%{public}d, mtu=%{public}d',
      vpnConfig.addresses.length, vpnConfig.routes?.length ?? 0, vpnConfig.mtu ?? 0);

    // 4. 创建 VPN 连接，获取 TUN fd
    this.tunFd = await this.vpnConnection!.create(vpnConfig);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'VPN created, tunFd=%{public}d', this.tunFd);

    // 5. 启动 Native 层 WireGuard + 数据转发
    const nativeConfig: WgNativeConfig = {
      privateKey: wg.privateKey || '',
      peerPublicKey: wg.peerPublicKey || '',
      presharedKey: wg.presharedKey || '',
      endpointIp: resolvedIp,
      endpointPort: endpoint.serverPort,
      keepalive: wg.persistentKeepalive || 25
    };

    const ret: number = wgNative.startVpn(this.tunFd, socketFd, nativeConfig);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Native startVpn result=%{public}d', ret);
    if (ret < 0) {
      throw new Error('Native startVpn failed: ' + ret);
    }
  }

  onDestroy(): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'WireGuardVpnAbility onDestroy');
    this.stopStatusBroadcast();
    this.publishDisconnected('disconnected');
    try {
      wgNative.stopVpn();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'stopVpn error: %{public}s', msg);
    }
    this.destroyVpn();
  }

  // 定时把 native 的真实状态/流量经 commonEventManager 回传 UI 进程
  private startStatusBroadcast(): void {
    if (this.statusTimer !== -1) {
      return;
    }
    this.statusTimer = setInterval(() => {
      this.publishStatus();
    }, 1500);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'status broadcast started');
  }

  private stopStatusBroadcast(): void {
    if (this.statusTimer !== -1) {
      clearInterval(this.statusTimer);
      this.statusTimer = -1;
    }
  }

  private publishStatus(): void {
    let raw: string = '';
    try {
      raw = wgNative.getStatus();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'getStatus failed: %{public}s', msg);
      return;
    }
    if (!raw) {
      return;
    }
    const params: Record<string, Object> = { 'configId': this.activeConfigId };
    const options: commonEventManager.CommonEventPublishData = { data: raw, parameters: params };
    commonEventManager.publish(APP_CONSTANTS.VPN_STATUS_EVENT, options, (err: BusinessError) => {
      if (err && err.code) {
        hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'publish status failed: %{public}d', err.code);
      }
    });
  }

  // 广播一次终态（disconnected / failed），让 UI 立即离开 connecting/connected
  private publishDisconnected(state: string): void {
    const payload: string =
      '{"connected":false,"handshakeAgeSec":-1,"rxBytes":0,"txBytes":0,"state":"' + state + '"}';
    const params: Record<string, Object> = { 'configId': this.activeConfigId };
    const options: commonEventManager.CommonEventPublishData = { data: payload, parameters: params };
    commonEventManager.publish(APP_CONSTANTS.VPN_STATUS_EVENT, options, (err: BusinessError) => {
      if (err && err.code) {
        hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'publish disconnected failed: %{public}d', err.code);
      }
    });
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
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Foreground wantAgent ready: %{public}s', JSON.stringify(agent));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to prepare notification: %{public}s', msg);
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
    this.udpFd = -1;
  }
}
