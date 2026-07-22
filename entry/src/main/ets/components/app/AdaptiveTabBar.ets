import { TYPOGRAPHY, getString } from '../../common/DesignSystem';

@Component
export struct AdaptiveTabBar {
  @Prop currentIndex: number = 0;
  @Prop vertical: boolean = false;
  onChange?: (index: number) => void;

  private selectTab(index: number): void {
    if (index === this.currentIndex) {
      return;
    }
    this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.onChange?.(index);
    });
  }

  @Builder
  HorizontalItem(index: number, label: string, icon: Resource) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary')])
      if (this.currentIndex === index) {
        Text(label)
          .fontSize(TYPOGRAPHY.body_sm.size)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .maxLines(1)
      }
    }
    .justifyContent(FlexAlign.Center)
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.currentIndex === index ? $r('app.color.primary_bg') : Color.Transparent)
    .borderRadius(22)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .accessibilityDescription(this.currentIndex === index
      ? getString($r('app.string.accessibility_selected')) : '')
    .onClick(() => {
      this.selectTab(index);
    })
  }

  @Builder
  VerticalItem(index: number, label: string, icon: Resource) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary')])
      Text(label)
        .fontSize(TYPOGRAPHY.caption.size)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(60)
    .height(52)
    .backgroundColor(this.currentIndex === index ? $r('app.color.primary_bg') : Color.Transparent)
    .borderRadius(16)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .accessibilityDescription(this.currentIndex === index
      ? getString($r('app.string.accessibility_selected')) : '')
    .onClick(() => {
      this.selectTab(index);
    })
  }

  build() {
    if (this.vertical) {
      Column({ space: 4 }) {
        this.VerticalItem(0, getString($r('app.string.tab_tunnels')), $r('sys.symbol.wifi'))
        this.VerticalItem(1, getString($r('app.string.page_settings')), $r('sys.symbol.list_bullet'))
      }
      .padding(6)
      .backgroundColor($r('app.color.glass_bar'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .borderRadius(28)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
      .margin({ left: 16 })
    } else {
      Row({ space: 4 }) {
        this.HorizontalItem(0, getString($r('app.string.tab_tunnels')), $r('sys.symbol.wifi'))
        this.HorizontalItem(1, getString($r('app.string.page_settings')), $r('sys.symbol.list_bullet'))
      }
      .padding(6)
      .backgroundColor($r('app.color.glass_bar'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .borderRadius(28)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
    }
  }
}
