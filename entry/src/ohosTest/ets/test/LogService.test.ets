import { describe, it, expect } from '@ohos/hypium';
import { logService } from '../../../main/ets/service/LogService';

const PRIVATE_KEY = 'yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=';
const PRESHARED_KEY = 'xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=';

export default function logServiceTest() {
  describe('LogServiceTest', () => {
    it('redactsIniKeysRegardlessOfCase', 0, () => {
      logService.clearLogs();
      logService.addLog('A', 'info', 'privatekey = ' + PRIVATE_KEY + '\nPRESHAREDKEY=' + PRESHARED_KEY);
      const report = logService.exportReport('A');
      expect(report.includes(PRIVATE_KEY)).assertFalse();
      expect(report.includes(PRESHARED_KEY)).assertFalse();
      expect(report.includes('[REDACTED]')).assertTrue();
    });

    it('redactsJsonKeys', 0, () => {
      logService.clearLogs();
      const json = '{"privateKey":"' + PRIVATE_KEY + '","presharedKey":"' + PRESHARED_KEY + '"}';
      logService.addLog('B', 'error', json);
      const report = logService.exportReport('B');
      expect(report.includes(PRIVATE_KEY)).assertFalse();
      expect(report.includes(PRESHARED_KEY)).assertFalse();
      expect(report.includes('[REDACTED]')).assertTrue();
    });
  });
}
