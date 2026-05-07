import { SPACING, RADIUS, TYPOGRAPHY } from '../../common/DesignSystem';
import type { RuntimeLogEntry } from '../../model/WgConfig';

@Component
export struct RuntimeLogList {
  @Prop logs: RuntimeLogEntry[] = [];

  private getLevelColor(level: string): ResourceColor {
    if (level === 'error') {
      return $r('app.color.danger');
    } else if (level === 'warning') {
      return $r('app.color.warning');
    } else if (level === 'debug') {
      return $r('app.color.text_tertiary');
    } else {
      return $r('app.color.text_secondary');
    }
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  }

  build() {
    Column({ space: SPACING.xs }) {
      Text(getContext().resourceManager.getStringSync($r('app.string.section_logs').id))
        .fontSize(TYPOGRAPHY.title_sm.size)
        .fontWeight(TYPOGRAPHY.title_sm.weight)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: SPACING.xs })

      if (this.logs.length === 0) {
        Text('暂无日志')
          .fontSize(TYPOGRAPHY.caption.size)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(SPACING.md)
      } else {
        ForEach(this.logs.slice(-20), (log: RuntimeLogEntry) => {
          Row() {
            Text(this.formatTime(log.timestamp))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
              .width(44)

            Text(log.message)
              .fontSize(TYPOGRAPHY.caption.size)
              .fontColor(this.getLevelColor(log.level))
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(SPACING.xs)
        }, (log: RuntimeLogEntry) => log.id)
      }
    }
    .width('100%')
  }
}
