import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { UIContext } from '@kit.ArkUI';
import { getString } from '../common/DesignSystem';
import { APP_CONSTANTS } from '../common/Constants';
import { ConfigParser, ParseResult } from './ConfigParser';

const TAG = 'ImportActions';

// 导入动作从原「添加配置」整页抽出，供 FAB 菜单等入口直接调用（无需整页）。
export class ImportActions {
  static isQrScanSupported(): boolean {
    return canIUse('SystemCapability.Multimedia.Scan.ScanBarcode');
  }

  private static toast(ctx: UIContext, msg: string): void {
    try {
      ctx.getPromptAction().showToast({ message: msg, duration: 2500 });
    } catch (e) {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'toast failed');
    }
  }

  private static handleResult(ctx: UIContext, stack: NavPathStack, result: ParseResult): void {
    if (result.success && result.config) {
      stack.pushPath({ name: 'ConfigPreview', param: result.config });
    } else {
      ImportActions.toast(ctx,
        ConfigParser.resolveErrorMessage(result.error ?? $r('app.string.error_parse_config'), ctx));
    }
  }

  static manualCreate(stack: NavPathStack): void {
    stack.pushPath({ name: 'ConfigEdit' });
  }

  static pasteConfig(stack: NavPathStack): void {
    // READ_PASTEBOARD is system_basic on API 22. A third-party app should let
    // the user paste into an input field instead of reading the clipboard.
    stack.pushPath({ name: 'PasteConfig' });
  }

  static async fromFile(ctx: UIContext, stack: NavPathStack): Promise<void> {
    try {
      const hostCtx = ctx.getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(hostCtx);
      const uris: string[] = await documentPicker.select({ maxSelectNumber: 1 });
      if (!uris || uris.length === 0) {
        return; // 用户取消
      }
      const uri = uris[0];
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(file.fd);
        const size = stat.size > 0 ? stat.size : 8192;
        const buf = new ArrayBuffer(size);
        const len = fs.readSync(file.fd, buf);
        const decoder = util.TextDecoder.create('utf-8');
        const text = decoder.decodeToString(new Uint8Array(buf, 0, len));
        let name = '';
        const slash = uri.lastIndexOf('/');
        const base = slash >= 0 ? uri.substring(slash + 1) : uri;
        const dot = base.lastIndexOf('.');
        name = dot > 0 ? base.substring(0, dot) : base;
        ImportActions.handleResult(ctx, stack, ConfigParser.parseFromText(text, name));
      } finally {
        fs.closeSync(file);
      }
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'file error: %{public}s', e?.message ?? String(err));
      ImportActions.toast(ctx, getString($r('app.string.error_file_read')));
    }
  }

  static async scanQR(ctx: UIContext, stack: NavPathStack): Promise<void> {
    if (canIUse('SystemCapability.Multimedia.Scan.ScanBarcode')) {
      try {
        const hostCtx = ctx.getHostContext() as common.UIAbilityContext;
        const options: scanBarcode.ScanOptions = {
          scanTypes: [scanCore.ScanType.QR_CODE],
          enableMultiMode: false,
          enableAlbum: true
        };
        const result = await scanBarcode.startScanForResult(hostCtx, options);
        if (!result || !result.originalValue || result.originalValue.length === 0) {
          return;
        }
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'qr text len=%{public}d', result.originalValue.length);
        ImportActions.handleResult(ctx, stack, ConfigParser.parseFromText(result.originalValue));
      } catch (err) {
        const e = err as BusinessError;
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'scan error: %{public}s', e?.message ?? String(err));
        ImportActions.toast(ctx, getString($r('app.string.error_qr_scan')));
      }
    } else {
      ImportActions.toast(ctx, getString($r('app.string.error_qr_not_supported')));
    }
  }
}
