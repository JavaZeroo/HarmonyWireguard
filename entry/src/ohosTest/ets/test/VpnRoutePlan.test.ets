import { describe, it, expect } from '@ohos/hypium';
import { buildVpnRoutePlan } from '../../../main/ets/common/VpnRoutePlan';

export default function vpnRoutePlanTest() {
  describe('VpnRoutePlanTest', () => {
    it('emptyAllowedIpsUsesIpv4DefaultFallback', 0, () => {
      const plan = buildVpnRoutePlan('   ');
      expect(plan.usedDefaultIpv4Fallback).assertTrue();
      expect(plan.acceptedIpv4Routes.length).assertEqual(1);
      expect(plan.acceptedIpv4Routes[0].address).assertEqual('0.0.0.0');
      expect(plan.acceptedIpv4Routes[0].prefixLength).assertEqual(0);
      expect(plan.ignoredRoutes.length).assertEqual(0);
    });

    it('validIpv4RoutesAreAccepted', 0, () => {
      const plan = buildVpnRoutePlan('10.0.0.0/8, 192.168.1.0/24');
      expect(plan.usedDefaultIpv4Fallback).assertFalse();
      expect(plan.acceptedIpv4Routes.length).assertEqual(2);
      expect(plan.acceptedIpv4Routes[0].address).assertEqual('10.0.0.0');
      expect(plan.acceptedIpv4Routes[0].prefixLength).assertEqual(8);
      expect(plan.acceptedIpv4Routes[1].address).assertEqual('192.168.1.0');
      expect(plan.acceptedIpv4Routes[1].prefixLength).assertEqual(24);
      expect(plan.ignoredRoutes.length).assertEqual(0);
    });

    it('ipv6OnlyNeverBecomesIpv4DefaultRoute', 0, () => {
      const plan = buildVpnRoutePlan('::/0, 2001:db8::/32');
      expect(plan.usedDefaultIpv4Fallback).assertFalse();
      expect(plan.acceptedIpv4Routes.length).assertEqual(0);
      expect(plan.ignoredRoutes.length).assertEqual(2);
      expect(plan.ignoredRoutes[0].reason).assertEqual('ipv6_not_supported');
      expect(plan.ignoredRoutes[1].reason).assertEqual('ipv6_not_supported');
    });

    it('invalidOnlyNeverBecomesIpv4DefaultRoute', 0, () => {
      const plan = buildVpnRoutePlan('999.1.1.1/24, 10.0.0.0/33, missing-prefix');
      expect(plan.usedDefaultIpv4Fallback).assertFalse();
      expect(plan.acceptedIpv4Routes.length).assertEqual(0);
      expect(plan.ignoredRoutes.length).assertEqual(3);
      expect(plan.ignoredRoutes[0].reason).assertEqual('invalid_cidr');
      expect(plan.ignoredRoutes[1].reason).assertEqual('invalid_cidr');
      expect(plan.ignoredRoutes[2].reason).assertEqual('invalid_cidr');
    });

    it('mixedPlanPreservesAcceptedAndIgnoredEntries', 0, () => {
      const plan = buildVpnRoutePlan('0.0.0.0/0, ::/0, 10.20.0.0/16x');
      expect(plan.usedDefaultIpv4Fallback).assertFalse();
      expect(plan.acceptedIpv4Routes.length).assertEqual(1);
      expect(plan.acceptedIpv4Routes[0].input).assertEqual('0.0.0.0/0');
      expect(plan.ignoredRoutes.length).assertEqual(2);
      expect(plan.ignoredRoutes[0].reason).assertEqual('ipv6_not_supported');
      expect(plan.ignoredRoutes[1].reason).assertEqual('invalid_cidr');
    });

    it('commaOnlyInputIsInvalidNotEmptyFallback', 0, () => {
      const plan = buildVpnRoutePlan(' , ');
      expect(plan.usedDefaultIpv4Fallback).assertFalse();
      expect(plan.acceptedIpv4Routes.length).assertEqual(0);
      expect(plan.ignoredRoutes.length).assertEqual(2);
    });
  });
}
