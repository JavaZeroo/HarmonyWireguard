import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import type { common } from '@kit.AbilityKit';

// 深色模式：跟随系统 / 浅色 / 深色
export type ThemeMode = 'system' | 'light' | 'dark';

const STORE_NAME = 'app_settings';

// 所有布尔开关的默认值（与旧 SettingsPage @State 默认保持一致）
const BOOL_DEFAULTS: Record<string, boolean> = {
  autoConnect: false,
  reconnectOnNetworkChange: true,
  retryOnFailure: true,
  allowLanAccess: true,
  blockIpv6Leak: true,
  defaultMtuAuto: true,
  dnsLeakDetection: false,
  keyRevealConfirm: true,
  exportConfirm: true,
  autoClearClipboard: true,
  logSanitization: true,
  compactMode: false,
  statusBarTraffic: false
};

// 显式 key 列表（ArkTS 不支持 Object.keys 遍历 Record）
const BOOL_KEYS: string[] = [
  'autoConnect', 'reconnectOnNetworkChange', 'retryOnFailure',
  'allowLanAccess', 'blockIpv6Leak', 'defaultMtuAuto', 'dnsLeakDetection',
  'keyRevealConfirm', 'exportConfirm', 'autoClearClipboard', 'logSanitization',
  'compactMode', 'statusBarTraffic'
];

class SettingsService {
  private store: preferences.Preferences | null = null;
  private appCtx: common.ApplicationContext | null = null;
  private bools: Record<string, boolean> = {};
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
        const def = BOOL_DEFAULTS[k] ?? false;
        this.bools[k] = this.store.getSync(k, def) as boolean;
      }
      // 载入主题
      this.theme = this.store.getSync('themeMode', 'system') as ThemeMode;
      this.applyTheme();
    } catch (e) {
      // 兜底：用默认值
      for (let i = 0; i < BOOL_KEYS.length; i++) {
        this.bools[BOOL_KEYS[i]] = BOOL_DEFAULTS[BOOL_KEYS[i]] ?? false;
      }
    }
  }

  getBool(key: string): boolean {
    const v = this.bools[key];
    if (v !== undefined) {
      return v;
    }
    return BOOL_DEFAULTS[key] ?? false;
  }

  setBool(key: string, value: boolean): void {
    this.bools[key] = value;
    if (this.store) {
      try {
        this.store.putSync(key, value);
        this.store.flush();
      } catch (e) {
        // ignore persist error
      }
    }
  }

  getTheme(): ThemeMode {
    return this.theme;
  }

  setTheme(mode: ThemeMode): void {
    this.theme = mode;
    if (this.store) {
      try {
        this.store.putSync('themeMode', mode);
        this.store.flush();
      } catch (e) {
        // ignore
      }
    }
    this.applyTheme();
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
