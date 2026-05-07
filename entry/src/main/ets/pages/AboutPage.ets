import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../common/DesignSystem';
import { SectionCard } from '../components/common/SectionCard';

@Entry
@Component
struct AboutPage {
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

        Text(getString($r('app.string.page_about')))
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

      Scroll() {
        Column({ space: SPACING.md }) {
          // App Info
          Column() {
            SymbolGlyph($r('sys.symbol.wifi'))
              .fontSize(64)
              .fontColor([$r('app.color.primary')])
              .margin({ bottom: SPACING.md })

            Text(getString($r('app.string.app_name')))
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
        .width('100%')
        .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
      }
      .width('100%')
      .layoutWeight(1)
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
