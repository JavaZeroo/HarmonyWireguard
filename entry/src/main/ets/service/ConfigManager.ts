import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { WgConfig } from '../model/WgConfig';

const DOMAIN = 0x0000;
const TAG = 'ConfigManager';
const PREF_NAME = 'wg_configs';
const KEY_CONFIGS = 'configs';

class ConfigManager {
  private pref: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    this.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
    hilog.info(DOMAIN, TAG, 'ConfigManager initialized');
  }

  getAllConfigs(): WgConfig[] {
    if (!this.pref) return [];
    const str = this.pref.getSync(KEY_CONFIGS, '[]') as string;
    try {
      return JSON.parse(str) as WgConfig[];
    } catch {
      return [];
    }
  }

  saveConfig(config: WgConfig): void {
    if (!this.pref) return;
    const configs = this.getAllConfigs();
    const idx = configs.findIndex(c => c.id === config.id);
    if (idx >= 0) {
      configs[idx] = config;
    } else {
      configs.push(config);
    }
    this.pref.putSync(KEY_CONFIGS, JSON.stringify(configs));
    this.pref.flush();
    hilog.info(DOMAIN, TAG, 'Config saved: %{public}s', config.name);
  }

  deleteConfig(id: string): void {
    if (!this.pref) return;
    const configs = this.getAllConfigs().filter(c => c.id !== id);
    this.pref.putSync(KEY_CONFIGS, JSON.stringify(configs));
    this.pref.flush();
    hilog.info(DOMAIN, TAG, 'Config deleted: %{public}s', id);
  }

  getConfigById(id: string): WgConfig | undefined {
    return this.getAllConfigs().find(c => c.id === id);
  }
}

export const configManager = new ConfigManager();
