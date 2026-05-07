import type { DiagnosticItem, TunnelDiagnosticState } from '../model/WgConfig';

export class DiagnosticService {
  static async runDiagnostics(tunnelId: string, endpoint: string): Promise<TunnelDiagnosticState> {
    const now = Date.now();

    const permission: DiagnosticItem = {
      id: 'permission',
      title: 'VPN 权限',
      status: 'pass',
      description: '已授权'
    };

    const endpointResolve: DiagnosticItem = {
      id: 'endpoint_resolve',
      title: 'Endpoint 解析',
      status: 'checking'
    };

    const endpointReachability: DiagnosticItem = {
      id: 'endpoint_reachability',
      title: 'Endpoint 连通性',
      status: 'checking'
    };

    const handshake: DiagnosticItem = {
      id: 'handshake',
      title: '握手状态',
      status: 'checking'
    };

    const dns: DiagnosticItem = {
      id: 'dns',
      title: 'DNS',
      status: 'checking'
    };

    const route: DiagnosticItem = {
      id: 'route',
      title: '路由',
      status: 'pass',
      description: 'AllowedIPs 已配置'
    };

    const ipv6: DiagnosticItem = {
      id: 'ipv6',
      title: 'IPv6',
      status: 'warning',
      description: 'IPv6 可能未接管',
      suggestion: '开启 IPv6 防泄漏'
    };

    const localNetwork: DiagnosticItem = {
      id: 'local_network',
      title: '本地网络',
      status: 'pass',
      description: '可访问本地网络'
    };

    // Simulate async checks
    await new Promise(resolve => setTimeout(resolve, 500));
    endpointResolve.status = 'pass';
    endpointResolve.description = '域名解析成功';

    await new Promise(resolve => setTimeout(resolve, 300));
    endpointReachability.status = 'pass';
    endpointReachability.description = '服务器可达';

    await new Promise(resolve => setTimeout(resolve, 200));
    handshake.status = 'pass';
    handshake.description = '最近握手正常';

    await new Promise(resolve => setTimeout(resolve, 200));
    dns.status = 'pass';
    dns.description = 'DNS 可用';

    return {
      tunnelId,
      permission,
      endpointResolve,
      endpointReachability,
      handshake,
      dns,
      route,
      ipv6,
      localNetwork,
      updatedAt: now
    };
  }
}
