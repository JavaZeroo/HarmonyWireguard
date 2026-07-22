import { describe, it, expect } from '@ohos/hypium';
import { DiagnosticService } from '../../../main/ets/service/DiagnosticService';
import type { TunnelRuntimeState, WgConfig } from '../../../main/ets/model/WgConfig';

const VALID_KEY = 'yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=';

function createConfig(allowedIPs: string = '0.0.0.0/0, ::/0'): WgConfig {
  return {
    id: 'diagnostic-test',
    name: 'Diagnostic Test',
    privateKey: VALID_KEY,
    address: '10.0.0.2/32',
    dns: '1.1.1.1',
    mtu: 1420,
    peerPublicKey: VALID_KEY,
    presharedKey: '',
    allowedIPs,
    endpoint: 'vpn.example.com:51820',
    persistentKeepalive: 25
  };
}

export default function diagnosticsTest() {
  describe('DiagnosticsTest', () => {
    it('disconnectedRuntimeNeverPasses', 0, () => {
      const items = DiagnosticService.evaluateLocal(createConfig(), null);
      expect(items[4].id).assertEqual('runtime');
      expect(items[4].status === 'pass').assertFalse();
    });

    it('ipv6OnlyRoutesFailWithoutIpv4Fallback', 0, () => {
      const items = DiagnosticService.evaluateLocal(createConfig('::/0'), null);
      expect(items[2].id).assertEqual('routes');
      expect(items[2].status).assertEqual('fail');
      expect(items[5].status).assertEqual('warning');
    });

    it('staleHandshakeIsWarning', 0, () => {
      const runtime: TunnelRuntimeState = {
        tunnelId: 'diagnostic-test',
        status: 'connected',
        lastHandshakeAt: Math.floor(Date.now() / 1000) - 600,
        rxBytes: 0,
        txBytes: 0,
        updatedAt: Date.now()
      };
      const items = DiagnosticService.evaluateLocal(createConfig('0.0.0.0/0'), runtime);
      expect(items[4].status).assertEqual('warning');
    });

    it('hostnameStartsAsRealPendingResolution', 0, () => {
      const items = DiagnosticService.evaluateLocal(createConfig(), null);
      expect(items[1].id).assertEqual('endpoint');
      expect(items[1].status).assertEqual('checking');
    });
  });
}
