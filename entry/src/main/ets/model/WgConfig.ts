export interface WgConfig {
  id: string;
  name: string;
  privateKey: string;
  address: string;
  dns: string;
  mtu: number;
  peerPublicKey: string;
  presharedKey: string;
  allowedIPs: string;
  endpoint: string;
  persistentKeepalive: number;
}

export interface WgStatus {
  connected: boolean;
  configId: string;
  rxBytes: number;
  txBytes: number;
  lastHandshake: number;
}
