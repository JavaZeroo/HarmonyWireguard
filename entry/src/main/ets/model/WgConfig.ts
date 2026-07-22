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

// 扩展进程通过 commonEvent 回传的实时状态负载（native getStatus 的 JSON）
export type WgTerminalState = 'disconnected' | 'failed';

export interface WgStatusPayload {
  connected: boolean;
  handshakeAgeSec: number;  // 距上次成功握手的秒数，-1 表示尚未握手
  rxBytes: number;
  txBytes: number;
  state?: WgTerminalState;
}

export type RouteModeType = 'global' | 'lanOnly' | 'custom';

export type TunnelStatusType = 'disconnected' | 'connecting' | 'connected' | 'failed';

export interface TunnelRuntimeState {
  tunnelId: string;
  status: TunnelStatusType;
  lastHandshakeAt?: number;
  rxBytes: number;
  txBytes: number;
  rxSpeed?: number;
  txSpeed?: number;
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
