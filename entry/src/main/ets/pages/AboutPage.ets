import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY } from '../common/DesignSystem';
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

        Text(getContext().resourceManager.getStringSync($r('app.string.page_about').id))
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

            Text(getContext().resourceManager.getStringSync($r('app.string.app_name').id))
              .fontSize(TYPOGRAPHY.title_md.size)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: SPACING.xs })

            Text('Version 1.0.0')
              .fontSize(TYPOGRAPHY.body_sm.size)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(SPACING.xl)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(RADIUS.lg)
          .alignItems(HorizontalAlign.Center)

          // Open Source
          SectionCard({ title: '开源协议' }) {
            Column() {
              Text('本应用使用了以下开源项目：')
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .margin({ bottom: SPACING.sm })

              Text('- WireGuard (GPLv2)')
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')

              Text('- HarmonyOS ArkUI')
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }

          // Privacy
          SectionCard({ title: '隐私说明' }) {
            Column() {
              Text('本应用仅在本地处理 WireGuard 配置信息，不会将您的私钥或配置上传到任何服务器。所有敏感数据均存储在设备本地。')
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }

          // Developer
          SectionCard({ title: '开发者' }) {
            Column() {
              Text('HarmonyWireguard Project')
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
