import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { PageHeader } from '../components/app/PageHeader';
import { SectionCard } from '../components/common/SectionCard';
import { ConfigParser, ParseResult } from '../service/ConfigParser';

@Component
export struct PasteConfigPage {
  pageStack: NavPathStack = new NavPathStack();
  @State content: string = '';
  @State errorMessage: string = '';
  @State contentViewportHeight: number = 0;

  private canImport(): boolean {
    return this.content.trim().length > 0;
  }

  private textAreaHeight(): number {
    if (this.contentViewportHeight <= 0) {
      return 320;
    }
    return Math.max(180, Math.min(640, this.contentViewportHeight - 152));
  }

  private importConfig(): void {
    if (!this.canImport()) {
      return;
    }
    const result: ParseResult = ConfigParser.parseFromText(this.content);
    if (result.success && result.config !== undefined) {
      this.errorMessage = '';
      this.pageStack.replacePath({ name: 'ConfigPreview', param: result.config });
      return;
    }
    this.errorMessage = ConfigParser.resolveErrorMessage(
      result.error ?? $r('app.string.error_parse_config'),
      this.getUIContext()
    );
  }

  build() {
    Column() {
      PageHeader({
        pageStack: this.pageStack,
        title: getString($r('app.string.page_paste_config')),
        actionText: getString($r('app.string.button_import')),
        isActionEnabled: this.canImport(),
        onAction: () => {
          this.importConfig();
        }
      })

      Scroll() {
        Column() {
          Column({ space: SPACING.md }) {
            Text(getString($r('app.string.hint_paste_config')))
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')

            SectionCard({ title: getString($r('app.string.section_config_text')) }) {
              Column({ space: SPACING.sm }) {
                TextArea({
                  placeholder: getString($r('app.string.placeholder_config_text')),
                  text: $$this.content
                })
                  .width('100%')
                  .height(this.textAreaHeight())
                  .fontSize(TYPOGRAPHY.body_sm.size)
                  .backgroundColor($r('app.color.surface_subtle'))
                  .border({ width: 1, color: $r('app.color.divider'), radius: RADIUS.md })
                  .padding(SPACING.sm)
                  .accessibilityText($r('app.string.section_config_text'))
                  .onChange(() => {
                    if (this.errorMessage.length > 0) {
                      this.errorMessage = '';
                    }
                  })

                if (this.errorMessage.length > 0) {
                  Text(this.errorMessage)
                    .fontSize(TYPOGRAPHY.caption.size)
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                }
              }
              .width('100%')
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding(SPACING.md)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .onAreaChange((_oldArea, newArea) => {
        const heightVp: number = this.getUIContext().px2vp(newArea.height as number);
        if (heightVp > 0) {
          this.contentViewportHeight = heightVp;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
