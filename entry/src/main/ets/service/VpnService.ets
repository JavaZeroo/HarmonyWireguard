/**
 * @deprecated VPN control has moved to WireGuardVpnAbility (VpnExtensionAbility).
 * This file is kept as a stub and may be removed in the future.
 */

class VpnService {
  isVpnRunning(): boolean {
    return false;
  }
}

export const vpnService = new VpnService();
