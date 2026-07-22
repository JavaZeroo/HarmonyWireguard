import { SPACING, RADIUS, TYPOGRAPHY, SHADOW, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';
import { PageHeader } from '../components/app/PageHeader';

@Component
export struct AboutPage {
  pageStack: NavPathStack = new NavPathStack();

  build() {
    Column() {
      PageHeader({ title: getString($r('app.string.page_about')), pageStack: this.pageStack })

      Scroll() {
        Column() {
        Column({ space: SPACING.md }) {
          // App Info
          Column() {
            Stack() {
              SymbolGlyph($r('sys.symbol.wifi'))
                .fontSize(44)
                .fontColor([$r('app.color.primary')])
            }
            .width(88)
            .height(88)
            .backgroundColor($r('app.color.primary_bg'))
            .borderRadius(RADIUS.xl)
            .shadow({ radius: 20, color: 'rgba(0,125,255,0.20)', offsetX: 0, offsetY: 6 })
            .margin({ bottom: SPACING.md })

            Text(getString($r('app.string.product_name')))
              .fontSize(TYPOGRAPHY.title_md.size)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: SPACING.xs })

            Text(getString($r('app.string.app_version')))
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(SPACING.xl)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(RADIUS.lg)
          .shadow({
            radius: SHADOW.sm.radius,
            color: SHADOW.sm.color,
            offsetX: SHADOW.sm.offsetX,
            offsetY: SHADOW.sm.offsetY
          })
          .alignItems(HorizontalAlign.Center)

          // Open Source
          SectionCard({ title: getString($r('app.string.label_open_source')) }) {
            Column() {
              Text(getString($r('app.string.open_source_desc')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .margin({ bottom: SPACING.sm })

              Text(getString($r('app.string.open_source_wireguard')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')

              Text(getString($r('app.string.open_source_arkui')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }

          // Privacy
          SectionCard({ title: getString($r('app.string.label_privacy')) }) {
            Column() {
              Text(getString($r('app.string.privacy_desc')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }

          // Developer
          SectionCard({ title: getString($r('app.string.label_developer')) }) {
            Column() {
              Text(getString($r('app.string.developer_name')))
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }
        }
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    // 页面间转场：入栈自右侧滑入 + 淡入，出栈反向，取代默认纯淡入淡出
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 40 }))
      .animation({ duration: 300, curve: Curve.Friction }))
  }
}
