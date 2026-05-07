import type { TunnelRuntimeState, TunnelStatusType } from '../model/WgConfig';
import { logService } from './LogService';

class TunnelRuntimeService {
  private states: Map<string, TunnelRuntimeState> = new Map();
  private timer: number = -1;
  private listeners: Set<(states: Map<string, TunnelRuntimeState>) => void> = new Set();

  startMonitoring(): void {
    if (this.timer !== -1) return;
    this.timer = setInterval(() => {
      this.updateStates();
    }, 1000);
  }

  stopMonitoring(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private updateStates(): void {
    for (const [id, state] of this.states) {
      if (state.status === 'connected') {
        state.rxBytes += Math.floor(Math.random() * 1024);
        state.txBytes += Math.floor(Math.random() * 512);
        state.rxSpeed = Math.floor(Math.random() * 50 * 1024);
        state.txSpeed = Math.floor(Math.random() * 20 * 1024);
        state.updatedAt = Date.now();
      }
    }
    this.notifyListeners();
  }

  setStatus(tunnelId: string, status: TunnelStatusType, error?: string): void {
    const existing = this.states.get(tunnelId);
    const now = Date.now();

    if (status === 'connected' && (!existing || existing.status !== 'connected')) {
      logService.addLog(tunnelId, 'info', '隧道已连接');
    } else if (status === 'failed') {
      logService.addLog(tunnelId, 'error', error || '连接失败');
    } else if (status === 'disconnected' && existing && existing.status === 'connected') {
      logService.addLog(tunnelId, 'info', '隧道已断开');
    }

    this.states.set(tunnelId, {
      tunnelId,
      status,
      rxBytes: existing?.rxBytes || 0,
      txBytes: existing?.txBytes || 0,
      rxSpeed: existing?.rxSpeed || 0,
      txSpeed: existing?.txSpeed || 0,
      lastHandshakeAt: status === 'connected' ? Math.floor(now / 1000) : existing?.lastHandshakeAt,
      latestError: error,
      updatedAt: now
    });

    this.notifyListeners();
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
