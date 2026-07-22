import { describe, it, expect } from '@ohos/hypium';
import { decodeWgStatusPayload } from '../../../main/ets/common/WgStatusCodec';

export default function statusPayloadTest() {
  describe('StatusPayloadCodecTest', () => {
    it('acceptsNativeHeartbeat', 0, () => {
      const payload = decodeWgStatusPayload(
        '{"connected":true,"handshakeAgeSec":4,"rxBytes":12,"txBytes":34}'
      );
      expect(payload === null).assertFalse();
      if (payload !== null) {
        expect(payload.connected).assertTrue();
        expect(payload.rxBytes).assertEqual(12);
      }
    });

    it('acceptsTerminalState', 0, () => {
      const payload = decodeWgStatusPayload(
        '{"connected":false,"handshakeAgeSec":-1,"rxBytes":0,"txBytes":0,"state":"failed"}'
      );
      expect(payload === null).assertFalse();
      if (payload !== null) {
        expect(payload.state).assertEqual('failed');
      }
    });

    it('rejectsMalformedJson', 0, () => {
      expect(decodeWgStatusPayload('{broken') === null).assertTrue();
    });

    it('rejectsNegativeCounters', 0, () => {
      const body = '{"connected":false,"handshakeAgeSec":-1,"rxBytes":-1,"txBytes":0}';
      expect(decodeWgStatusPayload(body) === null).assertTrue();
    });

    it('rejectsUnknownOrContradictoryState', 0, () => {
      const unknown = '{"connected":false,"handshakeAgeSec":-1,"rxBytes":0,"txBytes":0,"state":"idle"}';
      const contradictory =
        '{"connected":true,"handshakeAgeSec":1,"rxBytes":1,"txBytes":1,"state":"failed"}';
      expect(decodeWgStatusPayload(unknown) === null).assertTrue();
      expect(decodeWgStatusPayload(contradictory) === null).assertTrue();
    });
  });
}
