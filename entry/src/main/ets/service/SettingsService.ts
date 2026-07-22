import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import type { common } from '@kit.AbilityKit';

// 深色模式：跟随系统 / 浅色 / 深色
export type ThemeMode = 'system' | 'light' | 'dark';

export type BoolSettingKey =
  'autoConnect' |
  'reconnectOnNetworkChange' |
  'retryOnFailure' |
  'allowLanAccess' |
  'blockIpv6Leak' |
  'defaultMtuAuto' |
  'dnsLeakDetection' |
  'keyRevealConfirm' |
  'reportCopyConfirm' |
  'autoClearClipboard' |
  'logSanitization' |
  'compactMode' |
  'statusBarTraffic';

const STORE_NAME = 'app_settings';

// 所有布尔开关的默认值（与旧 SettingsPage @State 默认保持一致）
const BOOL_DEFAULTS: Record<BoolSettingKey, boolean> = {
  autoConnect: false,
  reconnectOnNetworkChange: true,
  retryOnFailure: true,
  allowLanAccess: true,
  blockIpv6Leak: true,
  defaultMtuAuto: true,
  dnsLeakDetection: false,
  keyRevealConfirm: true,
  reportCopyConfirm: true,
  autoClearClipboard: true,
  logSanitization: true,
  compactMode: false,
  statusBarTraffic: false
};

// 显式 key 列表（ArkTS 不支持 Object.keys 遍历 Record）
const BOOL_KEYS: BoolSettingKey[] = [
  'autoConnect', 'reconnectOnNetworkChange', 'retryOnFailure',
  'allowLanAccess', 'blockIpv6Leak', 'defaultMtuAuto', 'dnsLeakDetection',
  'keyRevealConfirm', 'reportCopyConfirm', 'autoClearClipboard', 'logSanitization',
  'compactMode', 'statusBarTraffic'
];

function createDefaultBools(): Record<BoolSettingKey, boolean> {
  return {
    autoConnect: BOOL_DEFAULTS.autoConnect,
    reconnectOnNetworkChange: BOOL_DEFAULTS.reconnectOnNetworkChange,
    retryOnFailure: BOOL_DEFAULTS.retryOnFailure,
    allowLanAccess: BOOL_DEFAULTS.allowLanAccess,
    blockIpv6Leak: BOOL_DEFAULTS.blockIpv6Leak,
    defaultMtuAuto: BOOL_DEFAULTS.defaultMtuAuto,
    dnsLeakDetection: BOOL_DEFAULTS.dnsLeakDetection,
    keyRevealConfirm: BOOL_DEFAULTS.keyRevealConfirm,
    reportCopyConfirm: BOOL_DEFAULTS.reportCopyConfirm,
    autoClearClipboard: BOOL_DEFAULTS.autoClearClipboard,
    logSanitization: BOOL_DEFAULTS.logSanitization,
    compactMode: BOOL_DEFAULTS.compactMode,
    statusBarTraffic: BOOL_DEFAULTS.statusBarTraffic
  };
}

function normalizeThemeMode(value: preferences.ValueType): ThemeMode {
  if (value === 'light' || value === 'dark' || value === 'system') {
    return value;
  }
  return 'system';
}

class SettingsService {
  private store: preferences.Preferences | null = null;
  private appCtx: common.ApplicationContext | null = null;
  private bools: Record<BoolSettingKey, boolean> = createDefaultBools();
  private theme: ThemeMode = 'system';

  init(ctx: common.UIAbilityContext): void {
    if (this.store) {
      return;
    }
    try {
      this.appCtx = ctx.getApplicationContext();
      this.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
      // 载入所有布尔项
      for (let i = 0; i < BOOL_KEYS.length; i++) {
        const k = BOOL_KEYS[i];
        const def = BOOL_DEFAULTS[k];
        const value = this.store.getSync(k, def);
        this.bools[k] = typeof value === 'boolean' ? value : def;
      }
      // 载入主题
      this.theme = normalizeThemeMode(this.store.getSync('themeMode', 'system'));
      this.applyTheme();
    } catch (e) {
      // 兜底：用默认值
      this.bools = createDefaultBools();
      this.theme = 'system';
      this.applyTheme();
    }
  }

  getBool(key: BoolSettingKey): boolean {
    return this.bools[key];
  }

  setBool(key: BoolSettingKey, value: boolean): boolean {
    if (!this.store) {
      return false;
    }
    const previous = this.bools[key];
    this.bools[key] = value;
    try {
      this.store.putSync(key, value);
      this.store.flushSync();
      return true;
    } catch (e) {
      this.bools[key] = previous;
      return false;
    }
  }

  getTheme(): ThemeMode {
    return this.theme;
  }

  setTheme(mode: ThemeMode): boolean {
    if (!this.store) {
      return false;
    }
    const normalizedMode = normalizeThemeMode(mode);
    const previous = this.theme;
    this.theme = normalizedMode;
    try {
      this.store.putSync('themeMode', normalizedMode);
      this.store.flushSync();
      this.applyTheme();
      return true;
    } catch (e) {
      this.theme = previous;
      this.applyTheme();
      return false;
    }
  }

  private applyTheme(): void {
    if (!this.appCtx) {
      return;
    }
    let mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.theme === 'light') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (this.theme === 'dark') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      this.appCtx.setColorMode(mode);
    } catch (e) {
      // ignore
    }
  }
}

export const settingsService = new SettingsService();
