import { vpnExtension } from '@kit.NetworkKit';
import type { WgConfig } from '../model/WgConfig';
import { buildVpnRoutePlan, PlannedIpv4Route } from './VpnRoutePlan';

export class EndpointInfo {
  serverIp: string;
  serverPort: number;
  constructor(serverIp: string, serverPort: number) {
    this.serverIp = serverIp;
    this.serverPort = serverPort;
  }
}

export function parseEndpoint(endpoint: string): EndpointInfo {
  if (endpoint.startsWith('[')) {
    const closingBracket = endpoint.indexOf(']');
    if (closingBracket > 0) {
      const ip = endpoint.substring(1, closingBracket);
      const portPart = endpoint.substring(closingBracket + 1);
      const port = portPart.startsWith(':') ? parseInt(portPart.substring(1)) : 51820;
      return new EndpointInfo(ip, port);
    }
  }
  const parts = endpoint.split(':');
  return new EndpointInfo(parts[0], parseInt(parts[1] || '51820'));
}

function parseLinkAddress(addr: string): vpnExtension.LinkAddress {
  const parts = addr.split('/');
  const ip = parts[0];
  const prefix = parts[1] ? parseInt(parts[1]) : 24;
  const isIPv6 = ip.includes(':');
  return {
    address: { address: ip, family: isIPv6 ? 2 : 1 },
    prefixLength: prefix
  };
}

// 把执行计划中的有效 IPv4 路由转成 VPN RouteInfo。
// 关键：protect() 已把 WireGuard 的 UDP socket 绑定到底层物理网卡，
// 所以即便这里下发 0.0.0.0/0 默认路由，握手/数据 UDP 包也不会回环进 TUN。
function toRouteInfo(route: PlannedIpv4Route): vpnExtension.RouteInfo {
  return {
    // 必须与系统真实创建的 TUN 网卡名一致（HarmonyOS 固定为 'vpn-tun'）。
    // 之前写 'wgtun0'（不存在的名字）导致 NetworkAddRoute 静默失败，
    // AllowedIPs 路由压根没装上，App 流量走物理网卡进不了隧道，内网不通。
    interface: 'vpn-tun',
    destination: {
      address: { address: route.address, family: 1 },
      prefixLength: route.prefixLength
    },
    gateway: { address: '0.0.0.0', family: 1 },
    hasGateway: false,
    isDefaultRoute: route.prefixLength === 0
  };
}

// 依据同一份执行计划构造路由表；只有 AllowedIPs 为空时计划才会生成 IPv4 默认回退。
function buildRoutes(allowedIPs: string): vpnExtension.RouteInfo[] {
  const plan = buildVpnRoutePlan(allowedIPs);
  const routes: vpnExtension.RouteInfo[] = [];
  for (const plannedRoute of plan.acceptedIpv4Routes) {
    routes.push(toRouteInfo(plannedRoute));
  }
  return routes;
}

// 构造 VpnConfig：addresses + routes(由 AllowedIPs 决定) + dns。
// 没有 routes 时系统只会把 TUN 同网段路由进隧道，用户真实流量不走 VPN，
// 因此必须显式下发路由（全隧道场景即 0.0.0.0/0）。
export function buildVpnConfig(config: WgConfig): vpnExtension.VpnConfig {
  const addresses: vpnExtension.LinkAddress[] = [parseLinkAddress(config.address)];

  const dnsAddresses: string[] = config.dns
    ? config.dns.split(',').map(s => s.trim()).filter(s => s.length > 0)
    : ['8.8.8.8'];

  return {
    addresses,
    routes: buildRoutes(config.allowedIPs),
    dnsAddresses,
    mtu: config.mtu || 1420,
    isIPv4Accepted: true,
    isIPv6Accepted: false,
    isBlocking: false,
    trustedApplications: [],
    blockedApplications: []
  };
}
