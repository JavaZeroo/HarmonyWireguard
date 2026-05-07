import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { formatBytes } from '../../common/Formatters';
import { SectionCard } from '../common/SectionCard';
import { TrafficChart } from '../diagnostics/TrafficChart';
import { HandshakeCard } from '../diagnostics/HandshakeCard';
import { DiagnosticChecklist } from '../diagnostics/DiagnosticChecklist';
import { RuntimeLogList } from '../diagnostics/RuntimeLogList';
import { ExportReportButton } from '../diagnostics/ExportReportButton';
import { configManager } from '../../service/ConfigManager';
import { DiagnosticService } from '../../service/DiagnosticService';
import { logService } from '../../service/LogService';
import { tunnelRuntimeService } from '../../service/TunnelRuntimeService';
import type { WgConfig, DiagnosticItem, TunnelRuntimeState, RuntimeLogEntry } from '../../model/WgConfig';
import { deriveRouteMode } from '../../common/Utils';

@Component
export struct TunnelDetailPanel {
  @Prop @Watch('onConfigIdChange') configId: string = '';
  @State config: WgConfig | null = null;
  @State runtime: TunnelRuntimeState | null = null;
  @State diagnostics: DiagnosticItem[] = [];
  @State logs: RuntimeLogEntry[] = [];
  @State isRunningDiagnostics: boolean = false;

  private timer: number = -1;

  aboutToAppear(): void {
    this.loadConfig();
    this.timer = setInterval(() => {
      this.refreshData();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private onConfigIdChange(): void {
    this.loadConfig();
  }

  private loadConfig(): void {
    if (!this.configId) {
      this.config = null;
      return;
    }
    const cfg = configManager.getConfigById(this.configId);
    if (cfg) {
      this.config = cfg;
      this.runtime = tunnelRuntimeService.getState(cfg.id) || null;
      this.logs = logService.getLogs(cfg.id);
      this.runDiagnostics();
    } else {
      this.config = null;
    }
  }

  private refreshData(): void {
    if (this.config) {
      this.runtime = tunnelRuntimeService.getState(this.config.id) || null;
      this.logs = logService.getLogs(this.config.id);
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
    switch (mode) {
      case 'global':
        return getString($r('app.string.route_global'));
      case 'lanOnly':
        return getString($r('app.string.route_lan_only'));
      default:
        return getString($r('app.string.route_custom'));
    }
  }

  private getStatusText(): string {
    if (!this.runtime) return getString($r('app.string.status_disconnected'));
    switch (this.runtime.status) {
      case 'connected':
        return getString($r('app.string.status_connected'));
      case 'connecting':
        return getString($r('app.string.status_connecting'));
      case 'failed':
        return getString($r('app.string.status_failed'));
      default:
        return getString($r('app.string.status_disconnected'));
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
    Scroll() {
      Column({ space: SPACING.md }) {
        if (!this.config) {
          Text(getString($r('app.string.error_config_not_found')))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        } else {
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
            .width('100%')
          }

          // Traffic
          if (this.runtime && (this.runtime.rxBytes > 0 || this.runtime.txBytes > 0)) {
            SectionCard({ title: getString($r('app.string.section_traffic')) }) {
              Column() {
                TrafficChart({
                  rxSpeed: this.runtime.rxSpeed || 0,
                  txSpeed: this.runtime.txSpeed || 0
                })

                Row() {
                  Column() {
                    Text(getString($r('app.string.traffic_total_rx')))
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
                    Text(getString($r('app.string.traffic_total_tx')))
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
          SectionCard({ title: getString($r('app.string.section_route_info')) }) {
            Column({ space: SPACING.xs }) {
              Row() {
                Text(getString($r('app.string.field_route_mode')))
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
                Text(getString($r('app.string.field_allowed_ips')))
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
                Text(getString($r('app.string.field_dns')))
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
                Text(getString($r('app.string.field_mtu')))
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
          SectionCard({ title: getString($r('app.string.section_diagnostics')) }) {
            DiagnosticChecklist({
              items: this.diagnostics,
              onRunAgain: () => {
                this.runDiagnostics();
              }
            })
          }

          // Logs
          SectionCard({ title: getString($r('app.string.section_logs')) }) {
            RuntimeLogList({ logs: this.logs })
          }

          ExportReportButton({
            onExport: () => {
              const report = this.config ? logService.exportReport(this.config.id) : logService.exportReport();
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
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
  }
}
