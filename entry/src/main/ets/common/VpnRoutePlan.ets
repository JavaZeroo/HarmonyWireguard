export type IgnoredRouteReason = 'ipv6_not_supported' | 'invalid_cidr';

export class PlannedIpv4Route {
  input: string;
  address: string;
  prefixLength: number;

  constructor(input: string, address: string, prefixLength: number) {
    this.input = input;
    this.address = address;
    this.prefixLength = prefixLength;
  }
}

export class IgnoredRouteEntry {
  input: string;
  reason: IgnoredRouteReason;

  constructor(input: string, reason: IgnoredRouteReason) {
    this.input = input;
    this.reason = reason;
  }
}

export class VpnRoutePlan {
  acceptedIpv4Routes: PlannedIpv4Route[];
  ignoredRoutes: IgnoredRouteEntry[];
  usedDefaultIpv4Fallback: boolean;

  constructor(
    acceptedIpv4Routes: PlannedIpv4Route[],
    ignoredRoutes: IgnoredRouteEntry[],
    usedDefaultIpv4Fallback: boolean
  ) {
    this.acceptedIpv4Routes = acceptedIpv4Routes;
    this.ignoredRoutes = ignoredRoutes;
    this.usedDefaultIpv4Fallback = usedDefaultIpv4Fallback;
  }
}

class ParsedCidr {
  address: string;
  prefixLength: number;
  isIpv6: boolean;

  constructor(address: string, prefixLength: number, isIpv6: boolean) {
    this.address = address;
    this.prefixLength = prefixLength;
    this.isIpv6 = isIpv6;
  }
}

const DECIMAL_PATTERN: RegExp = /^\d+$/;
const IPV6_GROUP_PATTERN: RegExp = /^[0-9a-fA-F]{1,4}$/;
const DEFAULT_IPV4_ROUTE: string = '0.0.0.0/0';

function isValidIpv4Address(address: string): boolean {
  const octets = address.split('.');
  if (octets.length !== 4) {
    return false;
  }
  for (const octet of octets) {
    if (!DECIMAL_PATTERN.test(octet)) {
      return false;
    }
    const value = parseInt(octet);
    if (value < 0 || value > 255) {
      return false;
    }
  }
  return true;
}

function countIpv6Groups(section: string, allowIpv4Tail: boolean): number {
  if (section.length === 0) {
    return 0;
  }
  const groups = section.split(':');
  let count = 0;
  for (let index = 0; index < groups.length; index++) {
    const group = groups[index];
    if (group.includes('.')) {
      if (!allowIpv4Tail || index !== groups.length - 1 || !isValidIpv4Address(group)) {
        return -1;
      }
      count += 2;
    } else {
      if (!IPV6_GROUP_PATTERN.test(group)) {
        return -1;
      }
      count++;
    }
  }
  return count;
}

function isValidIpv6Address(address: string): boolean {
  const compressionIndex = address.indexOf('::');
  if (compressionIndex >= 0) {
    if (compressionIndex !== address.lastIndexOf('::')) {
      return false;
    }
    const left = address.substring(0, compressionIndex);
    const right = address.substring(compressionIndex + 2);
    const leftCount = countIpv6Groups(left, false);
    const rightCount = countIpv6Groups(right, true);
    return leftCount >= 0 && rightCount >= 0 && leftCount + rightCount < 8;
  }
  return countIpv6Groups(address, true) === 8;
}

function parseCidr(input: string): ParsedCidr | null {
  const slashIndex = input.indexOf('/');
  if (slashIndex <= 0 || slashIndex !== input.lastIndexOf('/') || slashIndex === input.length - 1) {
    return null;
  }

  const address = input.substring(0, slashIndex);
  const prefixText = input.substring(slashIndex + 1);
  if (!DECIMAL_PATTERN.test(prefixText)) {
    return null;
  }
  const prefixLength = parseInt(prefixText);

  if (address.includes(':')) {
    if (prefixLength > 128 || !isValidIpv6Address(address)) {
      return null;
    }
    return new ParsedCidr(address, prefixLength, true);
  }

  if (prefixLength > 32 || !isValidIpv4Address(address)) {
    return null;
  }
  return new ParsedCidr(address, prefixLength, false);
}

/**
 * Builds the exact IPv4 route plan consumed by the HarmonyOS VPN builder.
 *
 * An empty AllowedIPs value keeps the historic IPv4 default-route fallback.
 * Any non-empty value is treated as explicit user intent: unsupported IPv6
 * and malformed CIDRs are recorded, but never converted into 0.0.0.0/0.
 */
export function buildVpnRoutePlan(allowedIPs: string): VpnRoutePlan {
  const accepted: PlannedIpv4Route[] = [];
  const ignored: IgnoredRouteEntry[] = [];
  if (allowedIPs.trim().length === 0) {
    accepted.push(new PlannedIpv4Route(DEFAULT_IPV4_ROUTE, '0.0.0.0', 0));
    return new VpnRoutePlan(accepted, ignored, true);
  }

  const entries = allowedIPs.split(',');
  for (const rawEntry of entries) {
    const entry = rawEntry.trim();
    const parsed = parseCidr(entry);
    if (parsed === null) {
      ignored.push(new IgnoredRouteEntry(entry, 'invalid_cidr'));
    } else if (parsed.isIpv6) {
      ignored.push(new IgnoredRouteEntry(entry, 'ipv6_not_supported'));
    } else {
      accepted.push(new PlannedIpv4Route(entry, parsed.address, parsed.prefixLength));
    }
  }
  return new VpnRoutePlan(accepted, ignored, false);
}
