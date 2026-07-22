import { describe, it, expect } from '@ohos/hypium';
import {
  parseEndpoint,
  deriveRouteMode,
  parseWireGuardConfig,
  resolvePersistentKeepalive,
  shouldApplyToggle,
  ToggleContext
}
  from '../../../main/ets/common/Utils';
import { ConfigParser } from '../../../main/ets/service/ConfigParser';

const VALID_CONFIG: string = '[Interface]\n'
  + 'PrivateKey = yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=\n'
  + 'Address = 10.0.0.2/32\n'
  + 'DNS = 1.1.1.1\n'
  + '[Peer]\n'
  + 'PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=\n'
  + 'Endpoint = vpn.example.com:51820\n'
  + 'AllowedIPs = 0.0.0.0/0, ::/0\n'
  + 'PersistentKeepalive = 25';

export default function configTest() {
  describe('ConfigLogicTest', () => {
    // ---- Endpoint 解析 ----
    it('parseEndpoint_hostPort', 0, () => {
      const ep = parseEndpoint('vpn.example.com:51820');
      expect(ep === null).assertFalse();
      if (ep !== null) {
        expect(ep.host).assertEqual('vpn.example.com');
        expect(ep.port).assertEqual(51820);
        expect(ep.isIPv6).assertEqual(false);
      }
    });

    it('parseEndpoint_ipv6', 0, () => {
      const ep = parseEndpoint('[2001:db8::1]:51820');
      expect(ep === null).assertFalse();
      if (ep !== null) {
        expect(ep.host).assertEqual('2001:db8::1');
        expect(ep.port).assertEqual(51820);
        expect(ep.isIPv6).assertEqual(true);
      }
    });

    it('parseEndpoint_invalid', 0, () => {
      expect(parseEndpoint('no-port') === null).assertTrue();
      expect(parseEndpoint('') === null).assertTrue();
    });

    // ---- 路由模式推导 ----
    it('deriveRouteMode_global', 0, () => {
      expect(deriveRouteMode('0.0.0.0/0, ::/0')).assertEqual('global');
    });

    it('deriveRouteMode_lanOnly', 0, () => {
      expect(deriveRouteMode('192.168.3.0/24, 10.0.0.0/24')).assertEqual('lanOnly');
    });

    it('deriveRouteMode_custom', 0, () => {
      expect(deriveRouteMode('1.2.3.0/24')).assertEqual('custom');
    });

    // ---- 配置解析 ----
    it('parseWireGuardConfig_valid', 0, () => {
      const parsed = parseWireGuardConfig(VALID_CONFIG);
      expect(parsed === null).assertFalse();
      if (parsed !== null) {
        expect(parsed.peerPublicKey).assertEqual('xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=');
        expect(parsed.endpoint).assertEqual('vpn.example.com:51820');
        expect(parsed.allowedIPs).assertEqual('0.0.0.0/0, ::/0');
      }
    });

    it('parseWireGuardConfig_missingKeys', 0, () => {
      expect(parseWireGuardConfig('[Interface]\nAddress = 10.0.0.2/32') === null).assertTrue();
    });

    it('configParser_validSucceeds', 0, () => {
      const r = ConfigParser.parseFromText(VALID_CONFIG);
      expect(r.success).assertTrue();
      if (r.config !== undefined) {
        expect(r.config.endpoint).assertEqual('vpn.example.com:51820');
        expect(deriveRouteMode(r.config.allowedIPs)).assertEqual('global');
      }
    });

    it('configParser_garbageFails', 0, () => {
      expect(ConfigParser.parseFromText('this is not a config').success).assertFalse();
    });

    it('configParser_ipv6OnlyFailsWithoutSilentIpv4Fallback', 0, () => {
      const ipv6Only = VALID_CONFIG.replace('0.0.0.0/0, ::/0', '::/0');
      expect(ConfigParser.parseFromText(ipv6Only).success).assertFalse();
    });

    it('configParser_invalidAllowedIpFails', 0, () => {
      const invalidRoute = VALID_CONFIG.replace('0.0.0.0/0, ::/0', '10.0.0.0/33');
      expect(ConfigParser.parseFromText(invalidRoute).success).assertFalse();
    });

    it('configParser_ipv6EndpointFailsEarly', 0, () => {
      const ipv6Endpoint = VALID_CONFIG.replace('vpn.example.com:51820', '[2001:db8::1]:51820');
      expect(ConfigParser.parseFromText(ipv6Endpoint).success).assertFalse();
    });

    it('configParser_invalidPresharedKeyFails', 0, () => {
      const invalidPsk = VALID_CONFIG.replace('[Peer]\n', '[Peer]\nPresharedKey = invalid\n');
      expect(ConfigParser.parseFromText(invalidPsk).success).assertFalse();
    });

    it('configParser_invalidKeepaliveFails', 0, () => {
      const invalidKeepalive = VALID_CONFIG.replace('PersistentKeepalive = 25', 'PersistentKeepalive = 70000');
      expect(ConfigParser.parseFromText(invalidKeepalive).success).assertFalse();
    });

    it('keepalive_explicitZeroRemainsDisabled', 0, () => {
      expect(resolvePersistentKeepalive(0)).assertEqual(0);
    });

    it('keepalive_missingLegacyValueUsesDefault', 0, () => {
      expect(resolvePersistentKeepalive(undefined)).assertEqual(25);
    });

    it('configParser_invalidAddressFails', 0, () => {
      const invalidAddress = VALID_CONFIG.replace('Address = 10.0.0.2/32', 'Address = 10.0.0.2/99');
      expect(ConfigParser.parseFromText(invalidAddress).success).assertFalse();
    });

    it('configParser_ipv6AddressFailsEarly', 0, () => {
      const ipv6Address = VALID_CONFIG.replace('Address = 10.0.0.2/32', 'Address = 2001:db8::2/128');
      expect(ConfigParser.parseFromText(ipv6Address).success).assertFalse();
    });

    it('configParser_invalidDnsHostnameFails', 0, () => {
      const invalidDns = VALID_CONFIG.replace('DNS = 1.1.1.1', 'DNS = not-an-ip');
      expect(ConfigParser.parseFromText(invalidDns).success).assertFalse();
    });

    it('configParser_ipv6DnsFailsEarly', 0, () => {
      const ipv6Dns = VALID_CONFIG.replace('DNS = 1.1.1.1', 'DNS = 2001:4860:4860::8888');
      expect(ConfigParser.parseFromText(ipv6Dns).success).assertFalse();
    });

    // ---- 回归守护：修复「点连接后连上又立刻断开」的开关去抖逻辑 ----
    it('toggle_freshConnect_allowed', 0, () => {
      const ctx: ToggleContext = { activeConfigId: '', connectingId: '', activeStatus: 'disconnected' };
      expect(shouldApplyToggle('A', true, ctx)).assertTrue();
    });

    it('toggle_connectWhileBusy_ignored', 0, () => {
      const ctx: ToggleContext = { activeConfigId: '', connectingId: 'A', activeStatus: 'connecting' };
      expect(shouldApplyToggle('B', true, ctx)).assertFalse();
    });

    it('toggle_reConnectActive_ignored', 0, () => {
      const ctx: ToggleContext = { activeConfigId: 'A', connectingId: '', activeStatus: 'connected' };
      expect(shouldApplyToggle('A', true, ctx)).assertFalse();
    });

    it('toggle_switchWhileActive_ignored', 0, () => {
      const ctx: ToggleContext = { activeConfigId: 'A', connectingId: '', activeStatus: 'connected' };
      expect(shouldApplyToggle('B', true, ctx)).assertFalse();
    });

    it('toggle_disconnectActive_allowed', 0, () => {
      const ctx: ToggleContext = { activeConfigId: 'A', connectingId: '', activeStatus: 'connected' };
      expect(shouldApplyToggle('A', false, ctx)).assertTrue();
    });

    it('toggle_disconnectInactive_ignored', 0, () => {
      // 伪 onChange 想断开一个并非当前激活的配置 → 必须忽略（否则会误断 / 连锁开关）
      const ctx: ToggleContext = { activeConfigId: 'A', connectingId: '', activeStatus: 'connected' };
      expect(shouldApplyToggle('B', false, ctx)).assertFalse();
    });
  });
}
