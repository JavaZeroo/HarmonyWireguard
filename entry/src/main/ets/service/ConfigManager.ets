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

  async init(context: Context): Promise<void> {
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

  saveConfig(config: WgConfig): void {
    if (!this.pref) {
      hilog.error(DOMAIN, TAG, 'Cannot save: preferences not initialized');
      return;
    }

    if (!config.id) {
      hilog.error(DOMAIN, TAG, 'Cannot save: config id is empty');
      return;
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
      this.pref.flush();
      hilog.info(DOMAIN, TAG, 'Config saved: %{public}s', config.name);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to save config: %{public}s', msg);
    }
  }

  deleteConfig(id: string): void {
    if (!this.pref) {
      hilog.error(DOMAIN, TAG, 'Cannot delete: preferences not initialized');
      return;
    }

    if (!id) {
      hilog.error(DOMAIN, TAG, 'Cannot delete: id is empty');
      return;
    }

    try {
      const configs = this.getAllConfigs().filter(c => c.id !== id);
      this.pref.putSync(KEY_CONFIGS, JSON.stringify(configs));
      this.pref.flush();
      hilog.info(DOMAIN, TAG, 'Config deleted: %{public}s', id);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to delete config: %{public}s', msg);
    }
  }

  getConfigById(id: string): WgConfig | undefined {
    if (!id) return undefined;
    return this.getAllConfigs().find(c => c.id === id);
  }

  // 把当前要连接的配置 id 写到 prefs —— 系统 VPN 授权对话框会丢掉 want.parameters，
  // extension 启动后只能靠 prefs 拿到要用哪条配置
  setActiveConfigId(id: string): void {
    if (!this.pref) return;
    try {
      this.pref.putSync(KEY_ACTIVE_ID, id);
      this.pref.flush();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to set active id: %{public}s', msg);
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

  getActiveConfig(): WgConfig | undefined {
    const id = this.getActiveConfigId();
    return id ? this.getConfigById(id) : undefined;
  }
}

export const configManager = new ConfigManager();
