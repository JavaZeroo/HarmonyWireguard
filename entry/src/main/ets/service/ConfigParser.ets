import type { WgConfig } from '../model/WgConfig';
import { parseWireGuardConfig, buildWgConfigFromParsed, parseEndpoint } from '../common/Utils';
import { validateBase64Key, validateCidr, validateDns, validateEndpoint, validateMtu }
  from '../common/Validators';
import { buildVpnRoutePlan } from '../common/VpnRoutePlan';
import { UIContext } from '@kit.ArkUI';

export interface ParseResult {
  success: boolean;
  config?: WgConfig;
  error?: string | Resource;
}

export class ConfigParser {
  static parseFromText(text: string, name?: string): ParseResult {
    const parsed = parseWireGuardConfig(text);
    if (!parsed) {
      return { success: false, error: $r('app.string.error_parse_config') };
    }

    if (!parsed.privateKey || parsed.privateKey.length === 0) {
      return { success: false, error: $r('app.string.error_missing_private_key') };
    }

    if (!validateBase64Key(parsed.privateKey)) {
      return { success: false, error: $r('app.string.error_invalid_key') };
    }
    if (!validateCidr(parsed.address)) {
      return { success: false, error: $r('app.string.error_invalid_cidr') };
    }
    if (parsed.address.includes(':')) {
      return { success: false, error: $r('app.string.error_ipv6_address_unsupported') };
    }
    if (!validateDns(parsed.dns)) {
      return { success: false, error: $r('app.string.error_invalid_dns') };
    }
    if (parsed.dns.includes(':')) {
      return { success: false, error: $r('app.string.error_ipv6_dns_unsupported') };
    }
    if (!validateMtu(parsed.mtu)) {
      return { success: false, error: $r('app.string.error_invalid_mtu') };
    }

    if (!parsed.peerPublicKey || parsed.peerPublicKey.length === 0) {
      return { success: false, error: $r('app.string.error_missing_public_key') };
    }

    if (!validateBase64Key(parsed.peerPublicKey)) {
      return { success: false, error: $r('app.string.error_invalid_key') };
    }
    if (parsed.presharedKey.length > 0 && !validateBase64Key(parsed.presharedKey)) {
      return { success: false, error: $r('app.string.error_invalid_key') };
    }

    if (!validateEndpoint(parsed.endpoint)) {
      return { success: false, error: $r('app.string.error_invalid_endpoint') };
    }
    if (parseEndpoint(parsed.endpoint)?.isIPv6 === true) {
      return { success: false, error: $r('app.string.error_ipv6_endpoint_unsupported') };
    }

    if (!parsed.allowedIPs || parsed.allowedIPs.trim().length === 0) {
      return { success: false, error: $r('app.string.error_empty_allowed_ips') };
    }
    const routePlan = buildVpnRoutePlan(parsed.allowedIPs);
    if (routePlan.ignoredRoutes.some(route => route.reason === 'invalid_cidr')) {
      return { success: false, error: $r('app.string.error_invalid_cidr') };
    }
    if (routePlan.acceptedIpv4Routes.length === 0) {
      return { success: false, error: $r('app.string.error_ipv4_route_required') };
    }
    if (parsed.persistentKeepalive < 0 || parsed.persistentKeepalive > 65535) {
      return { success: false, error: $r('app.string.error_invalid_keepalive') };
    }

    if (name && name.length > 0) {
      parsed.name = name;
    }

    const config = buildWgConfigFromParsed(parsed);
    return { success: true, config };
  }

  static resolveErrorMessage(message: string | Resource, ctx: UIContext): string {
    if (typeof message === 'string') {
      return message;
    }
    const host = ctx.getHostContext();
    if (!host) {
      return '';
    }
    try {
      return host.resourceManager.getStringSync(message.id);
    } catch {
      try {
        return host.resourceManager.getStringSync($r('app.string.error_unknown').id);
      } catch {
        return '';
      }
    }
  }
}
