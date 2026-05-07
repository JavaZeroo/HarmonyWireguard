import type { RuntimeLogEntry } from '../model/WgConfig';

const MAX_LOGS = 500;

class LogService {
  private logs: RuntimeLogEntry[] = [];

  addLog(tunnelId: string, level: RuntimeLogEntry['level'], message: string, detail?: string): void {
    const entry: RuntimeLogEntry = {
      id: Date.now().toString() + Math.random().toString(36).substring(2, 8),
      tunnelId,
      level,
      message: this.sanitize(message),
      detail: detail ? this.sanitize(detail) : undefined,
      timestamp: Date.now()
    };
    this.logs.push(entry);
    if (this.logs.length > MAX_LOGS) {
      this.logs.shift();
    }
  }

  getLogs(tunnelId?: string, limit: number = 100): RuntimeLogEntry[] {
    let result = tunnelId ? this.logs.filter(l => l.tunnelId === tunnelId) : [...this.logs];
    return result.slice(-limit);
  }

  clearLogs(): void {
    this.logs = [];
  }

  exportReport(tunnelId?: string): string {
    const logs = this.getLogs(tunnelId, MAX_LOGS);
    return logs.map(l => {
      const time = new Date(l.timestamp).toISOString();
      return `[${time}] [${l.level.toUpperCase()}] ${l.message}`;
    }).join('\n');
  }

  private sanitize(text: string): string {
    // Redact private keys
    let sanitized = text.replace(/PrivateKey\s*=\s*[A-Za-z0-9+/=]+/g, 'PrivateKey = [REDACTED]');
    sanitized = sanitized.replace(/PresharedKey\s*=\s*[A-Za-z0-9+/=]+/g, 'PresharedKey = [REDACTED]');
    return sanitized;
  }
}

export const logService = new LogService();
