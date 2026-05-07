import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { ConfigParser } from '../service/ConfigParser';

@Entry
@Component
struct ImportConfigPage {
  @State isLoading: boolean = false;

  private handleParseResult(result: import('../service/ConfigParser').ParseResult): void {
    if (result.success && result.config) {
      router.pushUrl({
        url: 'pages/ConfigPreviewPage',
        params: { config: result.config }
      });
    } else {
      const msg = ConfigParser.resolveErrorMessage(result.error || $r('app.string.error_parse_config'));
      try {
        this.getUIContext().getPromptAction().showToast({ message: msg, duration: 3000 });
      } catch {}
    }
  }

  private async importFromClipboard(): Promise<void> {
    this.isLoading = true;
    try {
      this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.toast_clipboard_not_impl')), duration: 2000 });
    } catch {}
    this.isLoading = false;
  }

  private async importFromFile(): Promise<void> {
    this.isLoading = true;
    try {
      this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.toast_file_not_impl')), duration: 2000 });
    } catch {}
    this.isLoading = false;
  }

  private async scanQRCode(): Promise<void> {
    this.isLoading = true;
    try {
      this.getUIContext().getPromptAction().showToast({ message: getString($r('app.string.toast_qr_not_impl')), duration: 2000 });
    } catch {}
    this.isLoading = false;
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
              $r('sys.symbol.folder'),
              getString($r('app.string.button_import_file')),
              getString($r('app.string.desc_import_file')),
              () => this.importFromFile()
            )

            this.ImportOptionCard(
              $r('sys.symbol.doc_text'),
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
