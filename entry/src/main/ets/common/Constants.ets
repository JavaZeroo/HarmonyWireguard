import type { TunnelBehavior } from '../model/WgConfig';

export interface AppConstants {
  DOMAIN: number;
  BUNDLE_NAME: string;
  VPN_ABILITY_NAME: string;
  // 扩展进程 -> UI 进程回传实时状态/流量的自定义 commonEvent 名
  VPN_STATUS_EVENT: string;
  APP_BACKGROUND_EVENT: string;
}

export interface DefaultConfig {
  ADDRESS: string;
  DNS: string;
  MTU: number;
  ALLOWED_IPS: string;
  KEEPALIVE: number;
  PORT: number;
}

export const APP_CONSTANTS: AppConstants = {
  DOMAIN: 0xA001,
  BUNDLE_NAME: 'com.javazeroo.harmonywireguard',
  VPN_ABILITY_NAME: 'WireGuardVpnAbility',
  VPN_STATUS_EVENT: 'com.javazeroo.harmonywireguard.VPN_STATUS',
  APP_BACKGROUND_EVENT: 'appBackground'
};

export const DEFAULT_CONFIG: DefaultConfig = {
  ADDRESS: '10.0.0.2/24',
  DNS: '8.8.8.8',
  MTU: 1420,
  ALLOWED_IPS: '0.0.0.0/0, ::/0',
  KEEPALIVE: 25,
  PORT: 51820
};

export const DEFAULT_TUNNEL_BEHAVIOR: TunnelBehavior = {
  autoConnect: false,
  reconnectOnNetworkChange: false,
  allowLanAccess: false,
  blockIpv6Leak: false
};
