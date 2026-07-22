import { SPACING, RADIUS, TYPOGRAPHY, getString } from '../../common/DesignSystem';
import { formatBytes } from '../../common/Formatters';
import { SectionCard } from '../common/SectionCard';
import { TrafficChart } from '../diagnostics/TrafficChart';
import { HandshakeCard } from '../diagnostics/HandshakeCard';
import { RuntimeLogList } from '../diagnostics/RuntimeLogList';
import { DiagnosticChecklist } from '../diagnostics/DiagnosticChecklist';
import { ExportReportButton } from '../diagnostics/ExportReportButton';
import { configManager } from '../../service/ConfigManager';
import { DiagnosticService, HANDSHAKE_FRESH_SECONDS } from '../../service/DiagnosticService';
import { logService } from '../../service/LogService';
import { tunnelRuntimeService } from '../../service/TunnelRuntimeService';
import type {
  DiagnosticItem,
  RuntimeLogEntry,
  TunnelDiagnosticState,
  TunnelRuntimeState,
  WgConfig
} from '../../model/WgConfig';
import { deriveRouteMode } from '../../common/Utils';
import { pasteboard } from '@kit.BasicServicesKit';

@Component
export struct TunnelDetailPanel {
  @Prop @Watch('onConfigIdChange') configId: string = '';
  // 详情内容最大宽度（缩进布局）：宽屏分栏时限宽居中，0 = 不限（手机全屏 Cover）。
  @Prop contentMaxWidth: number = 0;
  @Prop compact: boolean = false;
  @State config: WgConfig | null = null;
  @State runtime: TunnelRuntimeState | null = null;
  @State logs: RuntimeLogEntry[] = [];
  @State diagnostics: DiagnosticItem[] = [];
  @State isDiagnosing: boolean = false;
  @State isAllowedIpsExpanded: boolean = false;

  // 详情页发起的编辑/删除（由宿主 Index 提供实现：导航到编辑页 / 二次确认后删除并刷新）
  onEdit?: () => void;
  onDelete?: () => void;

  private unsubscribeRuntime?: () => void;
  private diagnosticRunId: number = 0;
  private isActive: boolean = false;
  private lastRuntimeDiagnosticKey: string = '';

  aboutToAppear(): void {
    this.isActive = true;
    this.loadConfig();
    this.unsubscribeRuntime = tunnelRuntimeService.subscribe((states) => {
      if (!this.config) {
        return;
      }
      const previousRuntime = this.runtime;
      const nextRuntime = states.get(this.config.id) ?? null;
      const statusChanged = nextRuntime?.status !== previousRuntime?.status;
      const nextDiagnosticKey = this.runtimeDiagnosticKey(nextRuntime);
      const diagnosticsChanged = nextDiagnosticKey !== this.lastRuntimeDiagnosticKey;
      this.runtime = nextRuntime;
      // Runtime heartbeats arrive every 1.5 s, while logs only change on a
      // status transition. Avoid filtering/copying the entire log buffer on every beat.
      if (statusChanged) {
        this.logs = logService.getLogs(this.config.id, 20);
      }
      if (diagnosticsChanged) {
        this.lastRuntimeDiagnosticKey = nextDiagnosticKey;
        this.runDiagnostics();
      }
    });
  }

  aboutToDisappear(): void {
    this.isActive = false;
    this.diagnosticRunId++;
    if (this.unsubscribeRuntime !== undefined) {
      this.unsubscribeRuntime();
      this.unsubscribeRuntime = undefined;
    }
  }

  private onConfigIdChange(): void {
    this.isAllowedIpsExpanded = false;
    this.loadConfig();
  }

  private runtimeDiagnosticKey(runtime: TunnelRuntimeState | null): string {
    if (runtime === null) {
      return 'disconnected';
    }
    if (runtime.status !== 'connected') {
      return runtime.status;
    }
    if (runtime.lastHandshakeAt === undefined) {
      return 'connected-waiting';
    }
    const ageSeconds = Math.max(0, Math.floor(Date.now() / 1000) - runtime.lastHandshakeAt);
    return ageSeconds > HANDSHAKE_FRESH_SECONDS ? 'connected-stale' : 'connected-fresh';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
    } catch {}
  }

  private async copyAllowedIps(): Promise<void> {
    if (this.config === null || this.config.allowedIPs.length === 0) {
      return;
    }
    try {
      const board = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.config.allowedIPs);
      await board.setData(data);
      this.showToast(getString($r('app.string.hint_copied')));
    } catch {
      this.showToast(getString($r('app.string.error_copy_failed')));
    }
  }

  private loadConfig(): void {
    if (!this.configId) {
      this.config = null;
      this.runtime = null;
      this.logs = [];
      this.diagnostics = [];
      this.lastRuntimeDiagnosticKey = '';
      this.diagnosticRunId++;
      return;
    }
    const cfg = configManager.getConfigById(this.configId);
    if (cfg) {
      this.config = cfg;
      this.runtime = tunnelRuntimeService.getState(cfg.id) || null;
      this.logs = logService.getLogs(cfg.id, 20);
      this.lastRuntimeDiagnosticKey = this.runtimeDiagnosticKey(this.runtime);
      this.runDiagnostics();
    } else {
      this.config = null;
      this.runtime = null;
      this.logs = [];
      this.diagnostics = [];
      this.lastRuntimeDiagnosticKey = '';
      this.diagnosticRunId++;
    }
  }

  private runDiagnostics(): void {
    if (this.config === null) {
      return;
    }
    const config = this.config;
    const runtime = this.runtime;
    const runId = ++this.diagnosticRunId;
    this.diagnostics = DiagnosticService.evaluateLocal(config, runtime);
    this.isDiagnosing = true;
    DiagnosticService.runDiagnostics(config, runtime)
      .then((state: TunnelDiagnosticState) => {
        if (!this.isActive || runId !== this.diagnosticRunId || this.config?.id !== state.tunnelId) {
          return;
        }
        this.diagnostics = state.items;
        this.isDiagnosing = false;
      })
      .catch(() => {
        if (this.isActive && runId === this.diagnosticRunId) {
          this.isDiagnosing = false;
        }
      });
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
      // 外层居中容器：宽屏时把限宽后的内容在详情区居中（缩进布局）。
      Column() {
      Column({ space: this.compact ? SPACING.sm : SPACING.md }) {
        if (!this.config) {
          Text(getString($r('app.string.error_config_not_found')))
            .fontSize(TYPOGRAPHY.body_lg.size)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        } else {
          // Status Summary
          SectionCard({ cardPadding: this.compact ? SPACING.md : SPACING.lg }) {
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

              Text(getString($r('app.string.field_endpoint')) + ': ' + this.config.endpoint)
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .margin({ bottom: SPACING.xs })

              Text(getString($r('app.string.field_address')) + ': ' + this.config.address)
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
          }

          // 仅在宿主提供真实动作时展示，避免出现点击无响应的伪按钮。
          if (this.onEdit !== undefined && this.onDelete !== undefined) {
            Row({ space: SPACING.md }) {
              Button(getString($r('app.string.button_edit')))
                .layoutWeight(1)
                .height(48)
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.primary'))
                .backgroundColor($r('app.color.primary_bg'))
                .borderRadius(RADIUS.md)
                .hoverEffect(HoverEffect.Highlight)
                .onClick(() => {
                  this.onEdit?.();
                })

              Button(getString($r('app.string.button_delete')))
                .layoutWeight(1)
                .height(48)
                .fontSize(TYPOGRAPHY.body_sm.size)
                .fontColor($r('app.color.danger'))
                .backgroundColor($r('app.color.danger_bg'))
                .borderRadius(RADIUS.md)
                .hoverEffect(HoverEffect.Highlight)
                .onClick(() => {
                  this.onDelete?.();
                })
            }
            .width('100%')
          }

          // Traffic
          if (this.runtime && (this.runtime.rxBytes > 0 || this.runtime.txBytes > 0)) {
            SectionCard({
              title: getString($r('app.string.section_traffic')),
              cardPadding: this.compact ? SPACING.sm : SPACING.md
            }) {
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
          SectionCard({
            title: getString($r('app.string.section_route_info')),
            cardPadding: this.compact ? SPACING.sm : SPACING.md
          }) {
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

              Column({ space: SPACING.xs }) {
                Row() {
                  Text(getString($r('app.string.field_allowed_ips')))
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.text_secondary'))
                    .layoutWeight(1)

                  Button(this.isAllowedIpsExpanded
                    ? getString($r('app.string.button_collapse'))
                    : getString($r('app.string.button_expand')))
                    .height(48)
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.primary'))
                    .backgroundColor(Color.Transparent)
                    .padding({ left: SPACING.sm, right: SPACING.sm })
                    .onClick(() => {
                      this.isAllowedIpsExpanded = !this.isAllowedIpsExpanded;
                    })

                  Button(getString($r('app.string.button_copy')))
                    .height(48)
                    .fontSize(TYPOGRAPHY.body_sm.size)
                    .fontColor($r('app.color.primary'))
                    .backgroundColor(Color.Transparent)
                    .padding({ left: SPACING.sm, right: SPACING.sm })
                    .onClick(() => {
                      this.copyAllowedIps();
                    })
                }
                .width('100%')

                Text(this.config.allowedIPs)
                  .fontSize(TYPOGRAPHY.body_sm.size)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                  .maxLines(this.isAllowedIpsExpanded ? 20 : 2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')

              Row() {
                Text(getString($r('app.string.field_dns')))
                  .fontSize(TYPOGRAPHY.body_sm.size)
                  .fontColor($r('app.color.text_secondary'))
                  .width('35%')

                Text(this.config.dns || getString($r('app.string.label_auto')))
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

                Text(this.config.mtu > 0 ? String(this.config.mtu) : getString($r('app.string.label_auto')))
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
          SectionCard({ cardPadding: this.compact ? SPACING.sm : SPACING.md }) {
            DiagnosticChecklist({
              items: this.diagnostics,
              isRunning: this.isDiagnosing,
              onRunAgain: () => {
                this.runDiagnostics();
              }
            })
          }

          // Logs
          SectionCard({
            title: getString($r('app.string.section_logs')),
            cardPadding: this.compact ? SPACING.sm : SPACING.md
          }) {
            RuntimeLogList({ logs: this.logs })
          }

          ExportReportButton({
            onExport: () => {
              return this.config ? logService.exportReport(this.config.id) : logService.exportReport();
            }
          })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth > 0 ? this.contentMaxWidth : 100000 })
      .padding({
        left: this.compact ? SPACING.sm : SPACING.md,
        right: this.compact ? SPACING.sm : SPACING.md,
        top: this.compact ? SPACING.sm : SPACING.md,
        bottom: SPACING.xl
      })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
  }
}
