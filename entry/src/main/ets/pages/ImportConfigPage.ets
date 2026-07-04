import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { APP_CONSTANTS } from '../common/Constants';
import { ConfigParser, ParseResult } from '../service/ConfigParser';

const TAG = 'ImportConfigPage';

@Entry
@Component
struct ImportConfigPage {
  @State isLoading: boolean = false;

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2500 });
    } catch (e) {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'toast failed: %{public}s', JSON.stringify(e) ?? '');
    }
  }

  private getCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private handleParseResult(result: ParseResult): void {
    if (result.success && result.config) {
      router.pushUrl({
        url: 'pages/ConfigPreviewPage',
        params: { config: result.config }
      });
    } else {
      const msg = ConfigParser.resolveErrorMessage(result.error ?? $r('app.string.error_parse_config'));
      this.toast(msg);
    }
  }

  private async importFromClipboard(): Promise<void> {
    this.isLoading = true;
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = await board.getData();
      if (!data || !data.hasType(pasteboard.MIMETYPE_TEXT_PLAIN)) {
        this.toast(getString($r('app.string.error_parse_config')));
        return;
      }
      const text = data.getPrimaryText();
      if (!text || text.trim().length === 0) {
        this.toast(getString($r('app.string.error_parse_config')));
        return;
      }
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'clipboard text len=%{public}d', text.length);
      this.handleParseResult(ConfigParser.parseFromText(text));
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(APP_CONSTANTS.DOMAIN, TAG,
        'clipboard import error: code=%{public}d msg=%{public}s',
        e?.code ?? -1, e?.message ?? String(err));
      this.toast('剪贴板读取失败: ' + (e?.message ?? String(err)));
    } finally {
      this.isLoading = false;
    }
  }

  private async importFromFile(): Promise<void> {
    this.isLoading = true;
    try {
      const documentPicker = new picker.DocumentViewPicker(this.getCtx());
      const uris: string[] = await documentPicker.select({
        maxSelectNumber: 1
      });
      if (!uris || uris.length === 0) {
        return; // 用户取消，不弹错误
      }
      const uri = uris[0];
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'picked uri=%{public}s', uri);

      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(file.fd);
        const size = stat.size > 0 ? stat.size : 8192;
        const buf = new ArrayBuffer(size);
        const len = fs.readSync(file.fd, buf);
        const decoder = util.TextDecoder.create('utf-8');
        const text = decoder.decodeToString(new Uint8Array(buf, 0, len));
        hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'file text len=%{public}d', text.length);

        // 从 URI 末段截一个默认名
        let name = '';
        const slash = uri.lastIndexOf('/');
        const base = slash >= 0 ? uri.substring(slash + 1) : uri;
        const dot = base.lastIndexOf('.');
        name = dot > 0 ? base.substring(0, dot) : base;

        this.handleParseResult(ConfigParser.parseFromText(text, name));
      } finally {
        fs.closeSync(file);
      }
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(APP_CONSTANTS.DOMAIN, TAG,
        'file import error: code=%{public}d msg=%{public}s',
        e?.code ?? -1, e?.message ?? String(err));
      this.toast('文件读取失败: ' + (e?.message ?? String(err)));
    } finally {
      this.isLoading = false;
    }
  }

  private async scanQRCode(): Promise<void> {
    this.isLoading = true;
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      };
      const result = await scanBarcode.startScanForResult(this.getCtx(), options);
      if (!result || !result.originalValue || result.originalValue.length === 0) {
        return;
      }
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'qr text len=%{public}d', result.originalValue.length);
      this.handleParseResult(ConfigParser.parseFromText(result.originalValue));
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(APP_CONSTANTS.DOMAIN, TAG,
        'qr scan error: code=%{public}d msg=%{public}s',
        e?.code ?? -1, e?.message ?? String(err));
      this.toast('扫码失败: ' + (e?.message ?? String(err)));
    } finally {
      this.isLoading = false;
    }
  }

  @Builder
  ImportOptionCard(icon: Resource, title: string, description: string, onClick: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(32)
        .fontColor([$r('app.color.primary')])
        .margin({ right: SPACING.md })

      Column() {
        Text(title)
          .fontSize(TYPOGRAPHY.body_lg.size)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text(description)
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ top: SPACING.xs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(20)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .padding(SPACING.lg)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(RADIUS.lg)
    .onClick(onClick)
  }

  build() {
    Column() {
      // Header
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            router.back();
          })

        Text(getString($r('app.string.page_import_config')))
          .fontSize(TYPOGRAPHY.title_sm.size)
          .fontWeight(TYPOGRAPHY.title_sm.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(24)
      }
      .width('100%')
      .height(56)
      .padding({ left: SPACING.md, right: SPACING.md })
      .backgroundColor($r('app.color.surface'))

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary'))
          Text(getString($r('app.string.label_loading')))
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: SPACING.md })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: SPACING.md }) {
            this.ImportOptionCard(
              $r('sys.symbol.camera'),
              getString($r('app.string.button_scan_qr')),
              getString($r('app.string.desc_scan_qr')),
              () => this.scanQRCode()
            )

            this.ImportOptionCard(
              $r('sys.symbol.doc'),
              getString($r('app.string.button_import_file')),
              getString($r('app.string.desc_import_file')),
              () => this.importFromFile()
            )

            this.ImportOptionCard(
              $r('sys.symbol.doc'),
              getString($r('app.string.button_import_clipboard')),
              getString($r('app.string.desc_import_clipboard')),
              () => this.importFromClipboard()
            )

            this.ImportOptionCard(
              $r('sys.symbol.doc'),
              getString($r('app.string.button_create_manual')),
              getString($r('app.string.desc_create_manual')),
              () => {
                router.pushUrl({ url: 'pages/ConfigEditPage' });
              }
            )
          }
          .width('100%')
          .padding(SPACING.md)
          .layoutWeight(1)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
      .opacity(0)
    PageTransitionExit({ duration: 200, curve: Curve.EaseIn })
      .opacity(1)
  }
}
