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

export interface TunnelBehavior {
  autoConnect: boolean;
  reconnectOnNetworkChange: boolean;
  allowLanAccess: boolean;
  blockIpv6Leak: boolean;
}

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
  status: 'pass' | 'warning' | 'fail' | 'checking';
  description?: string;
  suggestion?: string;
}

export interface TunnelDiagnosticState {
  tunnelId: string;
  permission: DiagnosticItem;
  endpointResolve: DiagnosticItem;
  endpointReachability: DiagnosticItem;
  handshake: DiagnosticItem;
  dns: DiagnosticItem;
  route: DiagnosticItem;
  ipv6: DiagnosticItem;
  localNetwork: DiagnosticItem;
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
