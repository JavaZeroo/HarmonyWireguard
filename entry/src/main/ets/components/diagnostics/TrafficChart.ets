import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import { formatSpeed } from '../../common/Formatters';

interface TrafficPoint {
  rx: number;
  tx: number;
}

@Component
export struct TrafficChart {
  @Prop rxSpeed: number = 0;
  @Prop txSpeed: number = 0;
  @State history: TrafficPoint[] = [];
  private timer: number = -1;
  private maxPoints: number = 60;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.history.push({ rx: this.rxSpeed, tx: this.txSpeed });
      if (this.history.length > this.maxPoints) {
        this.history.shift();
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('�?' + formatSpeed(this.rxSpeed))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
        }
        .layoutWeight(1)

        Column() {
          Text('�?' + formatSpeed(this.txSpeed))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.success'))
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: SPACING.md })

      // Placeholder for canvas chart
      Stack() {
        Row() {
          ForEach(this.history, (point: TrafficPoint, index: number) => {
            Column() {
              Column()
                .width(2)
                .height(point.rx > 0 ? Math.min(60, Math.max(4, point.rx / 1000)) : 2)
                .backgroundColor($r('app.color.primary'))
                .opacity(0.6)

              Column()
                .width(2)
                .height(point.tx > 0 ? Math.min(60, Math.max(4, point.tx / 1000)) : 2)
                .backgroundColor($r('app.color.success'))
                .opacity(0.6)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
          }, (point: TrafficPoint, index: number) => String(index))
        }
        .width('100%')
        .height(80)
        .padding({ left: 4, right: 4 })

        if (this.history.length === 0) {
          Text('等待数据...')
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .height(80)
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(RADIUS.md)
    }
    .width('100%')
  }
}
