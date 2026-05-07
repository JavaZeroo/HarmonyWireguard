export interface AppConstants {
  DOMAIN: number;
  BUNDLE_NAME: string;
  VPN_ABILITY_NAME: string;
}

export interface DefaultConfig {
  ADDRESS: string;
  DNS: string;
  MTU: number;
  ALLOWED_IPS: string;
  KEEPALIVE: number;
  PORT: number;
}

export interface ColorConstants {
  PRIMARY: string;
  PRIMARY_DARK: string;
  SUCCESS: string;
  WARNING: string;
  DANGER: string;
  INFO: string;
  TEXT_PRIMARY: string;
  TEXT_SECONDARY: string;
  TEXT_TERTIARY: string;
  BACKGROUND: string;
  CARD: string;
  CARD_SUBTLE: string;
  DIVIDER: string;
  SUCCESS_BG: string;
  WARNING_BG: string;
  DANGER_BG: string;
  PRIMARY_BG: string;
}

export const APP_CONSTANTS: AppConstants = {
  DOMAIN: 0x0000,
  BUNDLE_NAME: 'com.example.harmonywireguard',
  VPN_ABILITY_NAME: 'WireGuardVpnAbility'
};

export const DEFAULT_CONFIG: DefaultConfig = {
  ADDRESS: '10.0.0.2/24',
  DNS: '8.8.8.8',
  MTU: 1420,
  ALLOWED_IPS: '0.0.0.0/0, ::/0',
  KEEPALIVE: 25,
  PORT: 51820
};

export const COLORS: ColorConstants = {
  PRIMARY: '#007DFF',
  PRIMARY_DARK: '#0056CC',
  SUCCESS: '#00B386',
  WARNING: '#FF8800',
  DANGER: '#FA2C2C',
  INFO: '#007DFF',
  TEXT_PRIMARY: '#E6000000',
  TEXT_SECONDARY: '#99000000',
  TEXT_TERTIARY: '#66000000',
  BACKGROUND: '#F1F3F5',
  CARD: '#FFFFFF',
  CARD_SUBTLE: '#F7F9FA',
  DIVIDER: '#1F000000',
  SUCCESS_BG: '#E8F8F3',
  WARNING_BG: '#FFF3E0',
  DANGER_BG: '#FFEBEE',
  PRIMARY_BG: '#EAF4FF'
};
