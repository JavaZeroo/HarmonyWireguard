import { connection } from '@kit.NetworkKit';
import { getString } from '../common/DesignSystem';
import { parseEndpoint } from '../common/Utils';
import { buildVpnRoutePlan } from '../common/VpnRoutePlan';
import { validateBase64Key, validateCidr, validateDns, validateEndpoint, validateMtu }
  from '../common/Validators';
import type { DiagnosticItem, TunnelDiagnosticState, TunnelRuntimeState, WgConfig }
  from '../model/WgConfig';

const IPV4_PATTERN = /^\d+\.\d+\.\d+\.\d+$/;
const HANDSHAKE_FRESH_SECONDS = 180;

export class DiagnosticService {
  static evaluateLocal(config: WgConfig, runtime: TunnelRuntimeState | null): DiagnosticItem[] {
    return [
      DiagnosticService.checkConfiguration(config),
      DiagnosticService.createEndpointItem(config),
      DiagnosticService.checkRoutes(config),
      DiagnosticService.checkDns(config),
      DiagnosticService.checkRuntime(runtime),
      DiagnosticService.checkIpv6(config)
    ];
  }

  static async runDiagnostics(
    config: WgConfig,
    runtime: TunnelRuntimeState | null
  ): Promise<TunnelDiagnosticState> {
    const items = DiagnosticService.evaluateLocal(config, runtime);
    items[1] = await DiagnosticService.resolveEndpoint(config);
    return {
      tunnelId: config.id,
      items,
      updatedAt: Date.now()
    };
  }

  private static checkConfiguration(config: WgConfig): DiagnosticItem {
    const addressParts = config.address.split(',')
      .map((value: string) => value.trim())
      .filter((value: string) => value.length > 0);
    const isAddressValid = addressParts.length === 1 &&
      !addressParts[0].includes(':') && validateCidr(addressParts[0]);
    const isPresharedKeyValid = config.presharedKey.length === 0 || validateBase64Key(config.presharedKey);
    const isValid = validateBase64Key(config.privateKey) &&
      validateBase64Key(config.peerPublicKey) && isPresharedKeyValid &&
      isAddressValid && validateMtu(config.mtu);

    if (isValid) {
      return {
        id: 'configuration',
        title: getString($r('app.string.diag_configuration')),
        status: 'pass',
        description: getString($r('app.string.diag_configuration_valid'))
      };
    }
    return {
      id: 'configuration',
      title: getString($r('app.string.diag_configuration')),
      status: 'fail',
      description: getString($r('app.string.diag_configuration_invalid')),
      suggestion: getString($r('app.string.diag_configuration_suggestion'))
    };
  }

  private static createEndpointItem(config: WgConfig): DiagnosticItem {
    if (!validateEndpoint(config.endpoint)) {
      return DiagnosticService.invalidEndpointItem();
    }
    const endpoint = parseEndpoint(config.endpoint);
    if (endpoint === null) {
      return DiagnosticService.invalidEndpointItem();
    }
    if (endpoint.isIPv6) {
      return {
        id: 'endpoint',
        title: getString($r('app.string.diag_endpoint')),
        status: 'fail',
        description: getString($r('app.string.diag_endpoint_ipv6_unsupported')),
        suggestion: getString($r('app.string.diag_endpoint_ipv4_suggestion'))
      };
    }
    if (DiagnosticService.isIpv4Literal(endpoint.host)) {
      return {
        id: 'endpoint',
        title: getString($r('app.string.diag_endpoint')),
        status: 'pass',
        description: getString($r('app.string.diag_endpoint_ipv4'))
          .replace('%s', endpoint.host)
      };
    }
    return {
      id: 'endpoint',
      title: getString($r('app.string.diag_endpoint')),
      status: 'checking',
      description: getString($r('app.string.diag_endpoint_resolving'))
    };
  }

  private static async resolveEndpoint(config: WgConfig): Promise<DiagnosticItem> {
    const initial = DiagnosticService.createEndpointItem(config);
    if (initial.status !== 'checking') {
      return initial;
    }
    const endpoint = parseEndpoint(config.endpoint);
    if (endpoint === null) {
      return DiagnosticService.invalidEndpointItem();
    }
    try {
      const addresses = await connection.getAddressesByName(endpoint.host);
      for (let i = 0; i < addresses.length; i++) {
        const address = addresses[i].address;
        if (address.length > 0 && !address.includes(':')) {
          return {
            id: 'endpoint',
            title: getString($r('app.string.diag_endpoint')),
            status: 'pass',
            description: getString($r('app.string.diag_endpoint_resolved'))
              .replace('%s', address)
          };
        }
      }
      return DiagnosticService.endpointResolutionFailedItem();
    } catch {
      return DiagnosticService.endpointResolutionFailedItem();
    }
  }

  private static invalidEndpointItem(): DiagnosticItem {
    return {
      id: 'endpoint',
      title: getString($r('app.string.diag_endpoint')),
      status: 'fail',
      description: getString($r('app.string.diag_endpoint_invalid')),
      suggestion: getString($r('app.string.diag_endpoint_suggestion'))
    };
  }

  private static endpointResolutionFailedItem(): DiagnosticItem {
    return {
      id: 'endpoint',
      title: getString($r('app.string.diag_endpoint')),
      status: 'fail',
      description: getString($r('app.string.diag_endpoint_resolve_failed')),
      suggestion: getString($r('app.string.diag_endpoint_resolve_suggestion'))
    };
  }

  private static checkRoutes(config: WgConfig): DiagnosticItem {
    if (config.allowedIPs.trim().length === 0) {
      return {
        id: 'routes',
        title: getString($r('app.string.diag_routes')),
        status: 'fail',
        description: getString($r('app.string.diag_routes_empty')),
        suggestion: getString($r('app.string.diag_routes_suggestion'))
      };
    }
    const plan = buildVpnRoutePlan(config.allowedIPs);
    for (let i = 0; i < plan.ignoredRoutes.length; i++) {
      if (plan.ignoredRoutes[i].reason === 'invalid_cidr') {
        return {
          id: 'routes',
          title: getString($r('app.string.diag_routes')),
          status: 'fail',
          description: getString($r('app.string.diag_routes_invalid')),
          suggestion: getString($r('app.string.diag_routes_suggestion'))
        };
      }
    }
    if (plan.acceptedIpv4Routes.length === 0) {
      return {
        id: 'routes',
        title: getString($r('app.string.diag_routes')),
        status: 'fail',
        description: getString($r('app.string.diag_routes_ipv4_required')),
        suggestion: getString($r('app.string.diag_routes_suggestion'))
      };
    }
    return {
      id: 'routes',
      title: getString($r('app.string.diag_routes')),
      status: 'pass',
      description: getString($r('app.string.diag_routes_valid'))
        .replace('%d', String(plan.acceptedIpv4Routes.length))
    };
  }

  private static checkDns(config: WgConfig): DiagnosticItem {
    if (config.dns.trim().length === 0) {
      return {
        id: 'dns',
        title: getString($r('app.string.diag_dns')),
        status: 'warning',
        description: getString($r('app.string.diag_dns_default'))
      };
    }
    if (!validateDns(config.dns)) {
      return {
        id: 'dns',
        title: getString($r('app.string.diag_dns')),
        status: 'fail',
        description: getString($r('app.string.diag_dns_invalid')),
        suggestion: getString($r('app.string.diag_dns_suggestion'))
      };
    }
    const count = config.dns.split(',')
      .map((value: string) => value.trim())
      .filter((value: string) => value.length > 0).length;
    return {
      id: 'dns',
      title: getString($r('app.string.diag_dns')),
      status: 'pass',
      description: getString($r('app.string.diag_dns_valid')).replace('%d', String(count))
    };
  }

  private static checkRuntime(runtime: TunnelRuntimeState | null): DiagnosticItem {
    if (runtime === null || runtime.status === 'disconnected') {
      return {
        id: 'runtime',
        title: getString($r('app.string.diag_runtime')),
        status: 'warning',
        description: getString($r('app.string.diag_runtime_disconnected'))
      };
    }
    if (runtime.status === 'connecting') {
      return {
        id: 'runtime',
        title: getString($r('app.string.diag_runtime')),
        status: 'checking',
        description: getString($r('app.string.diag_runtime_connecting'))
      };
    }
    if (runtime.status === 'failed') {
      return {
        id: 'runtime',
        title: getString($r('app.string.diag_runtime')),
        status: 'fail',
        description: runtime.latestError || getString($r('app.string.diag_runtime_failed')),
        suggestion: getString($r('app.string.diag_runtime_suggestion'))
      };
    }
    if (runtime.lastHandshakeAt === undefined) {
      return {
        id: 'runtime',
        title: getString($r('app.string.diag_runtime')),
        status: 'warning',
        description: getString($r('app.string.diag_runtime_waiting_handshake'))
      };
    }
    const ageSeconds = Math.max(0, Math.floor(Date.now() / 1000) - runtime.lastHandshakeAt);
    if (ageSeconds > HANDSHAKE_FRESH_SECONDS) {
      return {
        id: 'runtime',
        title: getString($r('app.string.diag_runtime')),
        status: 'warning',
        description: getString($r('app.string.diag_runtime_handshake_stale'))
          .replace('%d', String(ageSeconds)),
        suggestion: getString($r('app.string.diag_runtime_suggestion'))
      };
    }
    return {
      id: 'runtime',
      title: getString($r('app.string.diag_runtime')),
      status: 'pass',
      description: getString($r('app.string.diag_runtime_handshake'))
        .replace('%d', String(ageSeconds))
    };
  }

  private static checkIpv6(config: WgConfig): DiagnosticItem {
    const requestsIpv6 = config.address.includes(':') || config.allowedIPs.includes(':') || config.dns.includes(':');
    if (requestsIpv6) {
      return {
        id: 'ipv6',
        title: getString($r('app.string.diag_ipv6')),
        status: 'warning',
        description: getString($r('app.string.diag_ipv6_unsupported')),
        suggestion: getString($r('app.string.diag_ipv6_suggestion'))
      };
    }
    return {
      id: 'ipv6',
      title: getString($r('app.string.diag_ipv6')),
      status: 'pass',
      description: getString($r('app.string.diag_ipv6_not_requested'))
    };
  }

  private static isIpv4Literal(host: string): boolean {
    if (!IPV4_PATTERN.test(host)) {
      return false;
    }
    const octets = host.split('.');
    for (let i = 0; i < octets.length; i++) {
      const value = parseInt(octets[i]);
      if (isNaN(value) || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }
}
