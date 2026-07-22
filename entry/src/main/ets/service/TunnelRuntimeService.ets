import type { TunnelRuntimeState, TunnelStatusType, WgStatusPayload } from '../model/WgConfig';
import { logService } from './LogService';
import { getString } from '../common/DesignSystem';

// ArkTS module: localized runtime log resources require the .ets side of the ArkTS/TS boundary.

class TunnelRuntimeService {
  private states: Map<string, TunnelRuntimeState> = new Map();
  private listeners: Set<(states: Map<string, TunnelRuntimeState>) => void> = new Set();

  // 由 UI 侧（Index）在收到扩展进程的 commonEvent 后调用，写入真实状态/流量。
  // payload 来自 native getStatus；configId 来自事件 parameters。
  applyStatus(tunnelId: string, p: WgStatusPayload): void {
    if (!tunnelId) {
      return;
    }
    const existing = this.states.get(tunnelId);
    const now = Date.now();

    // 状态机：connected 真值优先；否则看终态字段；再否则视为握手中/重连中
    let status: TunnelStatusType;
    if (p.connected) {
      status = 'connected';
    } else if (p.state === 'failed') {
      status = 'failed';
    } else if (p.state === 'disconnected') {
      status = 'disconnected';
    } else {
      status = 'connecting';
    }

    // 速率：仅在稳定 connected 且有上一拍基准时按字节差/时间差计算
    let rxSpeed = 0;
    let txSpeed = 0;
    if (p.connected && existing && existing.status === 'connected') {
      const dtMs = now - existing.updatedAt;
      if (dtMs > 200) {
        const dtSec = dtMs / 1000;
        rxSpeed = Math.max(0, Math.floor((p.rxBytes - existing.rxBytes) / dtSec));
        txSpeed = Math.max(0, Math.floor((p.txBytes - existing.txBytes) / dtSec));
      } else {
        rxSpeed = existing.rxSpeed || 0;
        txSpeed = existing.txSpeed || 0;
      }
    }

    // 上次握手绝对时间（unix 秒）= 现在 - 握手年龄；未握手则沿用旧值
    const lastHandshakeAt = p.connected && p.handshakeAgeSec >= 0
      ? Math.floor(now / 1000) - p.handshakeAgeSec
      : existing?.lastHandshakeAt;

    this.logTransition(tunnelId, existing, status);

    this.states.set(tunnelId, {
      tunnelId,
      status,
      rxBytes: p.rxBytes,
      txBytes: p.txBytes,
      rxSpeed,
      txSpeed,
      lastHandshakeAt,
      latestError: status === 'failed' ? existing?.latestError : undefined,
      updatedAt: now
    });

    this.notifyListeners();
  }

  // UI 侧主动设置的过渡态：点连接→connecting，点断开→disconnected，启动异常→failed
  setStatus(tunnelId: string, status: TunnelStatusType, error?: string): void {
    const existing = this.states.get(tunnelId);
    const now = Date.now();

    this.logTransition(tunnelId, existing, status, error);

    this.states.set(tunnelId, {
      tunnelId,
      status,
      rxBytes: existing?.rxBytes || 0,
      txBytes: existing?.txBytes || 0,
      rxSpeed: status === 'connected' ? (existing?.rxSpeed || 0) : 0,
      txSpeed: status === 'connected' ? (existing?.txSpeed || 0) : 0,
      lastHandshakeAt: existing?.lastHandshakeAt,
      latestError: error,
      updatedAt: now
    });

    this.notifyListeners();
  }

  private logTransition(
    tunnelId: string,
    existing: TunnelRuntimeState | undefined,
    status: TunnelStatusType,
    error?: string
  ): void {
    if (status === 'connected' && (!existing || existing.status !== 'connected')) {
      logService.addLog(tunnelId, 'info', getString($r('app.string.log_tunnel_connected')));
    } else if (status === 'failed' && (!existing || existing.status !== 'failed')) {
      logService.addLog(tunnelId, 'error', error || getString($r('app.string.log_tunnel_failed')));
    } else if (status === 'disconnected' && existing && existing.status === 'connected') {
      logService.addLog(tunnelId, 'info', getString($r('app.string.log_tunnel_disconnected')));
    }
  }

  getState(tunnelId: string): TunnelRuntimeState | undefined {
    return this.states.get(tunnelId);
  }

  resetState(tunnelId: string): void {
    this.states.delete(tunnelId);
    this.notifyListeners();
  }

  subscribe(callback: (states: Map<string, TunnelRuntimeState>) => void): () => void {
    this.listeners.add(callback);
    return () => {
      this.listeners.delete(callback);
    };
  }

  private notifyListeners(): void {
    for (const cb of this.listeners) {
      cb(this.states);
    }
  }
}

export const tunnelRuntimeService = new TunnelRuntimeService();
