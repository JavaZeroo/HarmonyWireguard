export interface TunnelBehavior {
  autoConnect: boolean;
  reconnectOnNetworkChange: boolean;
  allowLanAccess: boolean;
  blockIpv6Leak: boolean;
}

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
  // Optional for backward compatibility with configurations saved before behavior settings were persisted.
  behavior?: TunnelBehavior;
}

export interface WgStatus {
  connected: boolean;
  configId: string;
  rxBytes: number;
  txBytes: number;
  lastHandshake: number;
}

// 扩展进程通过 commonEvent 回传的实时状态负载（native getStatus 的 JSON）
export interface WgStatusPayload {
  connected: boolean;
  handshakeAgeSec: number;  // 距上次成功握手的秒数，-1 表示尚未握手
  rxBytes: number;
  txBytes: number;
  state?: string;           // 仅终态时带：'disconnected' | 'failed'
}

export interface WgInterfaceConfig {
  privateKeyRef: string;
  publicKey?: string;
  addresses: string[];
  dns: string[];
  mtu?: number;
  listenPort?: number;
}

export interface WgPeerConfig {
  publicKey: string;
  presharedKeyRef?: string;
  endpointHost: string;
  endpointPort: number;
  allowedIPs: string[];
  persistentKeepalive?: number;
}

export type RouteModeType = 'global' | 'lanOnly' | 'custom';

export interface TunnelProfile {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  interface: WgInterfaceConfig;
  peers: WgPeerConfig[];
  routeMode: RouteModeType;
  behavior: TunnelBehavior;
  createdAt: number;
  updatedAt: number;
}

export type TunnelStatusType = 'disconnected' | 'connecting' | 'connected' | 'failed';

export interface TunnelRuntimeState {
  tunnelId: string;
  status: TunnelStatusType;
  lastHandshakeAt?: number;
  rxBytes: number;
  txBytes: number;
  rxSpeed?: number;
  txSpeed?: number;
  endpointResolvedIp?: string;
  latestError?: string;
  updatedAt: number;
}

export interface DiagnosticItem {
  id: string;
  title: string;
  status: DiagnosticStatusType;
  description?: string;
  suggestion?: string;
}

export type DiagnosticStatusType = 'pass' | 'warning' | 'fail' | 'checking';

export interface TunnelDiagnosticState {
  tunnelId: string;
  items: DiagnosticItem[];
  updatedAt: number;
}

export interface RuntimeLogEntry {
  id: string;
  tunnelId: string;
  level: 'debug' | 'info' | 'warning' | 'error';
  message: string;
  detail?: string;
  timestamp: number;
}
