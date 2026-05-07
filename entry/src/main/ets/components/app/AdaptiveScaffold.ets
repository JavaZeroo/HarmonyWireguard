import { Breakpoint, getBreakpoint, SPACING } from '../../common/DesignSystem';
import display from '@ohos.display';

@Component
export struct AdaptiveScaffold {
  @State breakpoint: Breakpoint = Breakpoint.COMPACT;
  @State windowWidth: number = 360;

  @BuilderParam
  compactBuilder: () => void = this.defaultBuilder;
  @BuilderParam
  mediumBuilder: () => void = this.defaultBuilder;
  @BuilderParam
  expandedBuilder: () => void = this.defaultBuilder;

  @Builder
  defaultBuilder() {
    Column() {}
  }

  aboutToAppear(): void {
    this.updateBreakpoint();
  }

  private updateBreakpoint(): void {
    try {
      this.windowWidth = AppStorage.get<number>('windowWidth') ?? px2vp(display.getDefaultDisplaySync().width);
    } catch {
      this.windowWidth = 360;
    }
    this.breakpoint = getBreakpoint(this.windowWidth);
  }

  build() {
    Stack() {
      if (this.breakpoint === Breakpoint.COMPACT) {
        this.compactBuilder()
      } else if (this.breakpoint === Breakpoint.MEDIUM) {
        this.mediumBuilder()
      } else {
        this.expandedBuilder()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .onAreaChange((oldArea, newArea) => {
      if (newArea.width > 0) {
        this.windowWidth = px2vp(newArea.width as number);
        this.breakpoint = getBreakpoint(this.windowWidth);
      }
    })
  }
}
