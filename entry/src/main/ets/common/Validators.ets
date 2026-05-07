import { util } from '@kit.ArkTS';

export function validateBase64Key(key: string): boolean {
  if (!key || key.length === 0) return false;
  try {
    const base64Helper = new util.Base64Helper();
    const decoded = base64Helper.decodeSync(key.trim());
    return decoded.length === 32;
  } catch {
    return false;
  }
}

export function validateEndpoint(endpoint: string): boolean {
  if (!endpoint || endpoint.length === 0) return false;
  const ipv6Pattern = /^\[([0-9a-fA-F:]+)\]:(\d+)$/;
  const normalPattern = /^([^:]+):(\d+)$/;

  if (ipv6Pattern.test(endpoint)) {
    const match = endpoint.match(ipv6Pattern);
    if (match) {
      const port = parseInt(match[2]);
      return port >= 1 && port <= 65535;
    }
  }

  const match = endpoint.match(normalPattern);
  if (match) {
    const port = parseInt(match[2]);
    return port >= 1 && port <= 65535;
  }

  return false;
}

export function validateCidr(cidr: string): boolean {
  if (!cidr || cidr.length === 0) return false;
  const parts = cidr.split('/');
  if (parts.length !== 2) return false;
  const prefix = parseInt(parts[1]);
  if (isNaN(prefix)) return false;

  const ip = parts[0];
  if (ip.includes('.')) {
    if (prefix < 0 || prefix > 32) return false;
    const octets = ip.split('.');
    if (octets.length !== 4) return false;
    return octets.every(o => {
      const n = parseInt(o);
      return !isNaN(n) && n >= 0 && n <= 255;
    });
  }

  if (prefix < 0 || prefix > 128) return false;
  const ipv6Pattern = /^[0-9a-fA-F:]+$/;
  return ipv6Pattern.test(ip) && ip.includes(':');
}

export function validateDns(dns: string): boolean {
  if (!dns || dns.length === 0) return true;
  const entries = dns.split(',').map(s => s.trim()).filter(s => s.length > 0);
  return entries.every(entry => {
    if (entry.includes('.')) {
      const octets = entry.split('.');
      if (octets.length !== 4) return false;
      return octets.every(o => {
        const n = parseInt(o);
        return !isNaN(n) && n >= 0 && n <= 255;
      });
    }
    return true;
  });
}

export function validateMtu(mtu: number): boolean {
  if (mtu === 0) return true;
  return mtu >= 576 && mtu <= 1500;
}

export function validatePort(port: number): boolean {
  return port >= 1 && port <= 65535;
}
