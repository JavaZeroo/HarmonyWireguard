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
    // Key redaction is mandatory and is deliberately not controlled by a user setting.
    let sanitized = text.replace(/PrivateKey\s*=\s*[A-Za-z0-9+/=]+/gi, 'PrivateKey = [REDACTED]');
    sanitized = sanitized.replace(/PresharedKey\s*=\s*[A-Za-z0-9+/=]+/gi, 'PresharedKey = [REDACTED]');
    sanitized = sanitized.replace(/"privateKey"\s*:\s*"[^"]*"/gi, '"privateKey":"[REDACTED]"');
    sanitized = sanitized.replace(/"presharedKey"\s*:\s*"[^"]*"/gi, '"presharedKey":"[REDACTED]"');
    return sanitized;
  }
}

export const logService = new LogService();
