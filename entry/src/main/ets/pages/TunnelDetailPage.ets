import { router } from '@kit.ArkUI';
import { SPACING, RADIUS, TYPOGRAPHY } from '../common/DesignSystem';
import { formatBytes } from '../common/Formatters';
import { SectionCard } from '../components/common/SectionCard';
import { TrafficChart } from '../components/diagnostics/TrafficChart';
import { HandshakeCard } from '../components/diagnostics/HandshakeCard';
import { DiagnosticChecklist } from '../components/diagnostics/DiagnosticChecklist';
import { RuntimeLogList } from '../components/diagnostics/RuntimeLogList';
import { ExportReportButton } from '../components/diagnostics/ExportReportButton';
import { configManager } from '../service/ConfigManager';
import { DiagnosticService } from '../service/DiagnosticService';
import { logService } from '../service/LogService';
import { tunnelRuntimeService } from '../service/TunnelRuntimeService';
import type { WgConfig, DiagnosticItem, TunnelRuntimeState, RuntimeLogEntry } from '../model/WgConfig';
import { deriveRouteMode } from '../common/Utils';

@Entry
@Component
struct TunnelDetailPage {
  @State config: WgConfig | null = null;
  @State runtime: TunnelRuntimeState | null = null;
  @State diagnostics: DiagnosticItem[] = [];
  @State logs: RuntimeLogEntry[] = logService.getLogs();
  @State isRunningDiagnostics: boolean = false;

  private timer: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as object;
    const id = (params as Record<string, string>)['id'];
    if (id) {
      const cfg = configManager.getConfigById(id);
      if (cfg) {
        this.config = cfg;
        this.runtime = tunnelRuntimeService.getState(cfg.id) || null;
        this.runDiagnostics();
      }
    }

    this.timer = setInterval(() => {
      if (this.config) {
        this.runtime = tunnelRuntimeService.getState(this.config.id) || null;
        this.logs = logService.getLogs(this.config.id);
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
    }
  }

  private async runDiagnostics(): Promise<void> {
    if (!this.config || this.isRunningDiagnostics) return;
    this.isRunningDiagnostics = true;

    const result = await DiagnosticService.runDiagnostics(this.config.id, this.config.endpoint);
    this.diagnostics = [
      result.permission,
      result.endpointResolve,
      result.endpointReachability,
      result.handshake,
      result.dns,
      result.route,
      result.ipv6,
      result.localNetwork
    ];

    this.isRunningDiagnostics = false;
  }

  private getRouteModeLabel(): string {
    if (!this.config) return '';
    const mode = deriveRouteMode(this.config.allowedIPs);
    const rm = getContext().resourceManager;
    switch (mode) {
      case 'global':
        return rm.getStringSync($r('app.string.route_global').id);
      case 'lanOnly':
        return rm.getStringSync($r('app.string.route_lan_only').id);
      default:
        return rm.getStringSync($r('app.string.route_custom').id);
    }
  }

  private getStatusText(): string {
    if (!this.runtime) return getContext().resourceManager.getStringSync($r('app.string.status_disconnected').id);
    const rm = getContext().resourceManager;
    switch (this.runtime.status) {
      case 'connected':
        return rm.getStringSync($r('app.string.status_connected').id);
      case 'connecting':
        return rm.getStringSync($r('app.string.status_connecting').id);
      case 'failed':
        return rm.getStringSync($r('app.string.status_failed').id);
      default:
        return rm.getStringSync($r('app.string.status_disconnected').id);
    }
  }

  private getStatusColor(): ResourceColor {
    if (!this.runtime) return $r('app.color.text_tertiary');
    switch (this.runtime.status) {
      case 'connected':
        return $r('app.color.success');
      case 'connecting':
        return $r('app.color.primary');
      case 'failed':
        return $r('app.color.danger');
      default:
        return $r('app.color.text_tertiary');
    }
  }

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

        Text(this.config?.name || getContext().resourceManager.getStringSync($r('app.string.page_tunnel_detail').id))
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

      if (!this.config) {
        Text('配置不存在')
          .fontSize(TYPOGRAPHY.body_lg.size)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      } else {
        Scroll() {
          Column({ space: SPACING.md }) {
            // Status Summary
            SectionCard({ cardPadding: SPACING.lg }) {
              Column() {
                Row() {
                  Circle()
                    .width(12)
                    .height(12)
                    .fill(this.getStatusColor())
                    .margin({ right: SPACING.sm })

                  Text(this.getStatusText())
                    .fontSize(TYPOGRAPHY.title_md.size)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getStatusColor())
                }
                .width('100%')
                .margin({ bottom: SPACING.md })

                if (this.runtime?.lastHandshakeAt) {
                  HandshakeCard({ lastHandshakeAt: this.runtime.lastHandshakeAt })
                }

                if (this.config) {
                  Text('Endpoint: ' + this.config.endpoint)
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .margin({ bottom: SPACING.xs })

                  Text('Address: ' + this.config.address)
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                }
              }
              .width('100%')
            }

            // Traffic
            if (this.runtime && (this.runtime.rxBytes > 0 || this.runtime.txBytes > 0)) {
              SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_traffic').id) }) {
                Column() {
                  TrafficChart({
                    rxSpeed: this.runtime.rxSpeed || 0,
                    txSpeed: this.runtime.txSpeed || 0
                  })

                  Row() {
                    Column() {
                      Text(getContext().resourceManager.getStringSync($r('app.string.traffic_total_rx').id))
                        .fontSize(TYPOGRAPHY.caption.size)
                        .fontColor($r('app.color.text_secondary'))
                      Text(formatBytes(this.runtime.rxBytes))
                        .fontSize(TYPOGRAPHY.body_md.size)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Column() {
                      Text(getContext().resourceManager.getStringSync($r('app.string.traffic_total_tx').id))
                        .fontSize(TYPOGRAPHY.caption.size)
                        .fontColor($r('app.color.text_secondary'))
                      Text(formatBytes(this.runtime.txBytes))
                        .fontSize(TYPOGRAPHY.body_md.size)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .margin({ top: SPACING.md })
                }
                .width('100%')
              }
            }

            // Route Info
            SectionCard({ title: getContext().resourceManager.getStringSync($r('app.string.section_route_info').id) }) {
              Column({ space: SPACING.xs }) {
                Row() {
                  Text('路由模式')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('35%')

                  Text(this.getRouteModeLabel())
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.primary'))
                    .layoutWeight(1)
                    .textAlign(TextAlign.End)
                }
                .width('100%')

                Row() {
                  Text('AllowedIPs')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('35%')

                  Text(this.config.allowedIPs)
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .textAlign(TextAlign.End)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')

                Row() {
                  Text('DNS')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('35%')

                  Text(this.config.dns || 'Auto')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .textAlign(TextAlign.End)
                }
                .width('100%')

                Row() {
                  Text('MTU')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .width('35%')

                  Text(this.config.mtu > 0 ? String(this.config.mtu) : 'Auto')
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
              }
              .width('100%')
            }

            // Diagnostics
            SectionCard({}) {
            DiagnosticChecklist({
              items: this.diagnostics,
              onRunAgain: () => {
                this.runDiagnostics();
              }
            })
          }

            // Logs
            SectionCard({}) {
            RuntimeLogList({
              logs: this.logs
            })

            ExportReportButton({
              onExport: () => {
                let report = logService.exportReport();
                if (this.config) {
                  report = logService.exportReport(this.config.id);
                }
                console.info('Diagnostic report exported');
              }
            })
          }
          }
          .width('100%')
          .padding({ left: SPACING.md, right: SPACING.md, top: SPACING.md, bottom: SPACING.xl })
        }
        .width('100%')
        .layoutWeight(1)
      }
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
