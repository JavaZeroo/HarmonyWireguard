import type { WgConfig } from '../model/WgConfig';

export type RouteMode = 'global' | 'lanOnly' | 'custom';

export interface ParsedEndpoint {
  host: string;
  port: number;
  isIPv6: boolean;
}

export interface ParsedWireGuardConfig {
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

// A missing field in a legacy stored configuration keeps the historical
// default, while an explicit 0 must remain "disabled".
export function resolvePersistentKeepalive(value: number | undefined): number {
  return value === undefined ? 25 : value;
}

export function parseEndpoint(endpoint: string): ParsedEndpoint | null {
  if (!endpoint) return null;

  const ipv6Pattern = /^\[([0-9a-fA-F:]+)\]:(\d+)$/;
  const normalPattern = /^([^:]+):(\d+)$/;

  const ipv6Match = endpoint.match(ipv6Pattern);
  if (ipv6Match) {
    return { host: ipv6Match[1], port: parseInt(ipv6Match[2]), isIPv6: true };
  }

  const normalMatch = endpoint.match(normalPattern);
  if (normalMatch) {
    return { host: normalMatch[1], port: parseInt(normalMatch[2]), isIPv6: false };
  }

  return null;
}

export function deriveRouteMode(allowedIPs: string): RouteMode {
  if (!allowedIPs || allowedIPs.trim().length === 0) {
    return 'custom';
  }
  const entries = allowedIPs.split(',').map(s => s.trim()).filter(s => s.length > 0);
  const hasGlobalV4 = entries.includes('0.0.0.0/0');
  const hasGlobalV6 = entries.includes('::/0');

  if (hasGlobalV4 && hasGlobalV6) {
    return 'global';
  }

  // Check for private ranges only
  const privateRanges = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10', '169.254.0.0/16'];
  const allPrivate = entries.every(e => {
    if (e === '0.0.0.0/0' || e === '::/0') return false;
    return privateRanges.some(r => e.startsWith(r.split('/')[0].substring(0, r.indexOf('.')))) ||
      e.startsWith('10.') || e.startsWith('192.168.') || e.startsWith('172.');
  });

  if (allPrivate && entries.length > 0 && !hasGlobalV4 && !hasGlobalV6) {
    return 'lanOnly';
  }

  return 'custom';
}

export function routeModeToAllowedIPs(mode: RouteMode, customCidrs?: string[]): string {
  switch (mode) {
    case 'global':
      return '0.0.0.0/0, ::/0';
    case 'lanOnly':
      return customCidrs?.join(', ') || '192.168.0.0/16, 10.0.0.0/8';
    case 'custom':
      return customCidrs?.join(', ') || '';
    default:
      return '0.0.0.0/0, ::/0';
  }
}

export function parseWireGuardConfig(text: string): ParsedWireGuardConfig | null {
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith('#'));

  let inInterface = false;
  let inPeer = false;

  const result: Partial<ParsedWireGuardConfig> = {
    name: '',
    mtu: 0,
    presharedKey: '',
    persistentKeepalive: 0
  };

  for (const line of lines) {
    if (line.toLowerCase() === '[interface]') {
      inInterface = true;
      inPeer = false;
      continue;
    }
    if (line.toLowerCase() === '[peer]') {
      inInterface = false;
      inPeer = true;
      continue;
    }

    const eqIndex = line.indexOf('=');
    if (eqIndex < 0) continue;
    const key = line.substring(0, eqIndex).trim();
    const value = line.substring(eqIndex + 1).trim();

    if (inInterface) {
      switch (key.toLowerCase()) {
        case 'privatekey':
          result.privateKey = value;
          break;
        case 'address':
          result.address = value;
          break;
        case 'dns':
          result.dns = value;
          break;
        case 'mtu':
          result.mtu = parseInt(value) || 0;
          break;
      }
    } else if (inPeer) {
      switch (key.toLowerCase()) {
        case 'publickey':
          result.peerPublicKey = value;
          break;
        case 'presharedkey':
          result.presharedKey = value;
          break;
        case 'allowedips':
          result.allowedIPs = value;
          break;
        case 'endpoint':
          result.endpoint = value;
          break;
        case 'persistentkeepalive':
          result.persistentKeepalive = parseInt(value) || 0;
          break;
      }
    }
  }

  if (!result.privateKey || !result.peerPublicKey || !result.endpoint) {
    return null;
  }

  // Generate name from endpoint host if empty
  if (!result.name) {
    const ep = parseEndpoint(result.endpoint);
    result.name = ep ? ep.host : 'Untitled';
  }

  if (!result.address) {
    result.address = '10.0.0.2/24';
  }
  if (!result.dns) {
    result.dns = '';
  }
  if (!result.allowedIPs) {
    result.allowedIPs = '0.0.0.0/0, ::/0';
  }

  return result as ParsedWireGuardConfig;
}

export function buildWgConfigFromParsed(parsed: ParsedWireGuardConfig, id?: string): WgConfig {
  return {
    id: id || Date.now().toString(),
    name: parsed.name || 'Untitled',
    privateKey: parsed.privateKey,
    address: parsed.address || '10.0.0.2/24',
    dns: parsed.dns || '',
    mtu: parsed.mtu || 0,
    peerPublicKey: parsed.peerPublicKey,
    presharedKey: parsed.presharedKey || '',
    allowedIPs: parsed.allowedIPs || '0.0.0.0/0, ::/0',
    endpoint: parsed.endpoint,
    persistentKeepalive: parsed.persistentKeepalive || 0
  };
}

// 连接开关的当前上下文（用于过滤伪/矛盾的开关回调）。
export interface ToggleContext {
  activeConfigId: string;
  connectingId: string;
  activeStatus: string;
}

// 判断某次「连接/断开」动作是否应真正执行。
// 过滤掉：正在连接时的重复连接、对未激活配置的断开等——这些多由 UI 复用/重渲染
// 产生的伪 onChange 触发，若不拦截会导致「连上又立刻断开」。
export function shouldApplyToggle(configId: string, enable: boolean, ctx: ToggleContext): boolean {
  if (enable) {
    if (ctx.connectingId !== '') {
      return false; // 已有连接进行中
    }
    if (ctx.activeConfigId !== '' && ctx.activeConfigId !== configId &&
      (ctx.activeStatus === 'connected' || ctx.activeStatus === 'connecting')) {
      return false; // 必须先停止当前隧道，扩展不支持运行中重配置
    }
    if (ctx.activeConfigId === configId &&
      (ctx.activeStatus === 'connected' || ctx.activeStatus === 'connecting')) {
      return false; // 该配置已连接/连接中
    }
    return true;
  }
  // 断开：仅当该配置确为当前激活/正在连接的配置时才执行
  if (ctx.activeConfigId !== configId && ctx.connectingId !== configId) {
    return false;
  }
  return true;
}

export function formatEndpointShort(endpoint: string, maxLen: number = 24): string {
  if (!endpoint) return '';
  if (endpoint.length <= maxLen) return endpoint;
  const parsed = parseEndpoint(endpoint);
  if (!parsed) return endpoint.substring(0, maxLen) + '...';
  if (parsed.host.length > maxLen - 8) {
    return parsed.host.substring(0, maxLen - 8) + '...:' + parsed.port;
  }
  return endpoint;
}
