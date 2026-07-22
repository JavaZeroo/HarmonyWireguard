import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { WgConfig } from '../model/WgConfig';

const TAG = 'ConfigManager';
const PREF_NAME = 'wg_configs';
const KEY_CONFIGS = 'configs';
const KEY_ACTIVE_ID = 'active_config_id';
const DOMAIN = 0xA001;

class ConfigManager {
  private pref: preferences.Preferences | null = null;

  init(context: Context): void {
    try {
      this.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
      hilog.info(DOMAIN, TAG, 'ConfigManager initialized');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to init: %{public}s', msg);
      throw new Error(`ConfigManager init failed: ${msg}`);
    }
  }

  getAllConfigs(): WgConfig[] {
    if (!this.pref) {
      hilog.warn(DOMAIN, TAG, 'Preferences not initialized');
      return [];
    }

    try {
      const str = this.pref.getSync(KEY_CONFIGS, '[]') as string;
      const configs = JSON.parse(str) as WgConfig[];
      return Array.isArray(configs) ? configs : [];
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to parse configs: %{public}s', msg);
      return [];
    }
  }

  saveConfig(config: WgConfig): boolean {
    if (!this.pref) {
      hilog.error(DOMAIN, TAG, 'Cannot save: preferences not initialized');
      return false;
    }

    if (!config.id) {
      hilog.error(DOMAIN, TAG, 'Cannot save: config id is empty');
      return false;
    }

    const configs = this.getAllConfigs();
    const idx = configs.findIndex(c => c.id === config.id);

    if (idx >= 0) {
      configs[idx] = config;
    } else {
      configs.push(config);
    }

    try {
      this.pref.putSync(KEY_CONFIGS, JSON.stringify(configs));
      this.pref.flushSync();
      hilog.info(DOMAIN, TAG, 'Config saved: %{public}s', config.name);
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to save config: %{public}s', msg);
      return false;
    }
  }

  deleteConfig(id: string): boolean {
    if (!this.pref) {
      hilog.error(DOMAIN, TAG, 'Cannot delete: preferences not initialized');
      return false;
    }

    if (!id) {
      hilog.error(DOMAIN, TAG, 'Cannot delete: id is empty');
      return false;
    }

    if (this.getActiveConfigId() === id) {
      hilog.warn(DOMAIN, TAG, 'Cannot delete active config: %{public}s', id);
      return false;
    }

    try {
      const configs = this.getAllConfigs().filter(c => c.id !== id);
      this.pref.putSync(KEY_CONFIGS, JSON.stringify(configs));
      this.pref.flushSync();
      this.clearActiveConfigId(id);
      hilog.info(DOMAIN, TAG, 'Config deleted: %{public}s', id);
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to delete config: %{public}s', msg);
      return false;
    }
  }

  getConfigById(id: string): WgConfig | undefined {
    if (!id) return undefined;
    return this.getAllConfigs().find(c => c.id === id);
  }

  // 把当前要连接的配置 id 写到 prefs —— 系统 VPN 授权对话框会丢掉 want.parameters，
  // extension 启动后只能靠 prefs 拿到要用哪条配置
  setActiveConfigId(id: string): boolean {
    if (!this.pref || !id) return false;
    try {
      this.pref.putSync(KEY_ACTIVE_ID, id);
      // The VPN extension runs in another process and may read immediately
      // after startVpnExtensionAbility. Persist before starting it.
      this.pref.flushSync();
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to set active id: %{public}s', msg);
      return false;
    }
  }

  getActiveConfigId(): string {
    if (!this.pref) return '';
    try {
      return this.pref.getSync(KEY_ACTIVE_ID, '') as string;
    } catch {
      return '';
    }
  }

  // 仅在仍指向 expectedId 时清理，避免旧连接的异步终态误清除刚启动的新连接。
  clearActiveConfigId(expectedId?: string): boolean {
    if (!this.pref) return false;
    try {
      const currentId = this.getActiveConfigId();
      if (expectedId && currentId !== expectedId) {
        return true;
      }
      if (!currentId) {
        return true;
      }
      this.pref.putSync(KEY_ACTIVE_ID, '');
      this.pref.flushSync();
      hilog.info(DOMAIN, TAG, 'Active config id cleared');
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to clear active id: %{public}s', msg);
      return false;
    }
  }

  getActiveConfig(): WgConfig | undefined {
    const id = this.getActiveConfigId();
    if (!id) {
      return undefined;
    }
    const config = this.getConfigById(id);
    if (!config) {
      hilog.warn(DOMAIN, TAG, 'Active config no longer exists: %{public}s', id);
      this.clearActiveConfigId(id);
    }
    return config;
  }
}

export const configManager = new ConfigManager();
