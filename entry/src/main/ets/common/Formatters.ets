export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const idx = Math.min(i, sizes.length - 1);
  return parseFloat((bytes / Math.pow(k, idx)).toFixed(2)) + ' ' + sizes[idx];
}

export function formatBytesPerSecond(bytesPerSecond: number): string {
  return formatBytes(bytesPerSecond) + '/s';
}

export function formatDuration(seconds: number): string {
  if (seconds < 0) return '从未';
  if (seconds < 60) {
    return seconds + 's';
  } else if (seconds < 3600) {
    return Math.floor(seconds / 60) + 'min';
  } else {
    return Math.floor(seconds / 3600) + 'h ' + Math.floor((seconds % 3600) / 60) + 'min';
  }
}

export function formatHandshake(secondsAgo: number): string {
  if (secondsAgo < 0) {
    return '从未握手';
  }
  if (secondsAgo < 60) {
    return secondsAgo + '秒前握手';
  }
  return Math.floor(secondsAgo / 60) + '分钟前握手';
}

export function formatSpeed(bytesPerSecond: number): string {
  if (bytesPerSecond === 0) return '0 B/s';
  const k = 1024;
  const sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  const i = Math.floor(Math.log(bytesPerSecond) / Math.log(k));
  const idx = Math.min(i, sizes.length - 1);
  return parseFloat((bytesPerSecond / Math.pow(k, idx)).toFixed(1)) + ' ' + sizes[idx];
}
