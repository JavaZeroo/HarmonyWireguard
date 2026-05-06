export const APP_CONSTANTS = {
  DOMAIN: 0x0000,
  BUNDLE_NAME: 'com.example.harmonywireguard',
  VPN_ABILITY_NAME: 'WireGuardVpnAbility',
} as const;

export const DEFAULT_CONFIG = {
  ADDRESS: '10.0.0.2/24',
  DNS: '8.8.8.8',
  MTU: 1420,
  ALLOWED_IPS: '0.0.0.0/0, ::/0',
  KEEPALIVE: 25,
  PORT: 51820,
} as const;

export const COLORS = {
  PRIMARY: '#00AA00',
  DANGER: '#FF4444',
  SECONDARY: '#999',
  TEXT_PRIMARY: '#666',
  BACKGROUND: '#f5f5f5',
  CARD: '#fff',
} as const;
