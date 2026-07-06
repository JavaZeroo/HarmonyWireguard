import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { formatSpeed } from '../../common/Formatters';

interface TrafficPoint {
  rx: number;
  tx: number;
}

// 实时流量迷你折线图（真 Canvas，替换早期的假占位柱）。
// 复用品牌语义色：下行=primary，上行=success；低透明度面积填充 + 2px 线。
@Component
export struct TrafficChart {
  @Prop rxSpeed: number = 0;
  @Prop txSpeed: number = 0;
  @State history: TrafficPoint[] = [];
  private timer: number = -1;
  private maxPoints: number = 60;
  private isReady: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.history.push({ rx: this.rxSpeed, tx: this.txSpeed });
      if (this.history.length > this.maxPoints) {
        this.history.shift();
      }
      if (this.isReady) {
        this.draw();
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);

    const pts = this.history;
    const n = pts.length;
    if (n < 2) {
      return;
    }
    let max = 1;
    for (let i = 0; i < n; i++) {
      max = Math.max(max, pts[i].rx, pts[i].tx);
    }
    const stepX = w / (this.maxPoints - 1);
    const rx: number[] = [];
    const tx: number[] = [];
    for (let i = 0; i < n; i++) {
      rx.push(pts[i].rx);
      tx.push(pts[i].tx);
    }
    // 上行画在下面（先画），下行覆盖其上
    this.drawSeries(tx, max, w, h, stepX, '#00B386', 'rgba(0,179,134,0.12)');
    this.drawSeries(rx, max, w, h, stepX, '#007DFF', 'rgba(0,125,255,0.13)');
  }

  private drawSeries(values: number[], max: number, w: number, h: number,
    stepX: number, line: string, fill: string): void {
    const n = values.length;
    const x0 = w - (n - 1) * stepX; // 最新点贴右边，历史向左滚动
    const yOf = (v: number): number => h - (v / max) * (h - 6) - 3;

    // 面积
    this.ctx.beginPath();
    this.ctx.moveTo(x0, h);
    for (let i = 0; i < n; i++) {
      this.ctx.lineTo(x0 + i * stepX, yOf(values[i]));
    }
    this.ctx.lineTo(x0 + (n - 1) * stepX, h);
    this.ctx.closePath();
    this.ctx.fillStyle = fill;
    this.ctx.fill();

    // 折线
    this.ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const x = x0 + i * stepX;
      const y = yOf(values[i]);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    this.ctx.strokeStyle = line;
    this.ctx.lineWidth = 2;
    this.ctx.lineJoin = 'round';
    this.ctx.stroke();
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('↓')
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontColor($r('app.color.primary'))
          Text(formatSpeed(this.rxSpeed))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
            .margin({ left: SPACING.xs })
        }
        .layoutWeight(1)

        Row() {
          Text('↑')
            .fontSize(TYPOGRAPHY.body_md.size)
            .fontColor($r('app.color.success'))
          Text(formatSpeed(this.txSpeed))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.success'))
            .margin({ left: SPACING.xs })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .margin({ bottom: SPACING.sm })

      Stack() {
        Canvas(this.ctx)
          .width('100%')
          .height(72)
          .onReady(() => {
            this.isReady = true;
            this.draw();
          })

        if (this.history.length < 2) {
          Text(getString($r('app.string.hint_waiting_data')))
            .fontSize(TYPOGRAPHY.caption.size)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .height(72)
      .backgroundColor($r('app.color.surface_subtle'))
      .borderRadius(RADIUS.md)
      .clip(true)
    }
    .width('100%')
  }
}
