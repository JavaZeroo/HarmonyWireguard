import { RADIUS, SPACING, TYPOGRAPHY } from '../../common/DesignSystem';

const HEADER_SIDE_SLOT_WIDTH: number = 64;

@Component
export struct PageHeader {
  pageStack: NavPathStack | null = null;
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop actionText: string = '';
  @Prop isActionEnabled: boolean = true;

  onBack?: () => void;
  onAction?: () => void;

  private handleBack(): void {
    if (this.onBack) {
      this.onBack();
      return;
    }
    if (this.pageStack !== null) {
      this.pageStack.pop();
    }
  }

  build() {
    Row() {
      Row() {
        if (this.showBack) {
          Stack() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(24)
              .fontColor([$r('app.color.text_primary')])
          }
          .width(48)
          .height(48)
          .borderRadius(RADIUS.full)
          .hoverEffect(HoverEffect.Highlight)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText($r('app.string.accessibility_back'))
          .onClick(() => {
            this.handleBack();
          })
        }
      }
      .width(HEADER_SIDE_SLOT_WIDTH)
      .height('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.title)
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(TYPOGRAPHY.title_sm.weight)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        if (this.actionText.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.actionText)
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .maxLines(1)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: SPACING.sm, right: SPACING.sm, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(RADIUS.full)
          }
          .width('100%')
          .height(48)
          .enabled(this.isActionEnabled)
          .opacity(this.isActionEnabled ? 1 : 0.4)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(this.actionText)
          .hoverEffect(HoverEffect.Highlight)
          .stateStyles({
            pressed: {
              .opacity(0.82)
            }
          })
          .onClick(() => {
            if (this.isActionEnabled) {
              this.onAction?.();
            }
          })
        }
      }
      .width(HEADER_SIDE_SLOT_WIDTH)
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: SPACING.sm, right: SPACING.sm })
    .backgroundColor($r('app.color.surface'))
  }
}
