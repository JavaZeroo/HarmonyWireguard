import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { settingsService } from '../service/SettingsService';
import { APP_CONSTANTS } from '../common/Constants';
import { initializeDesignSystem } from '../common/DesignSystem';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initializeDesignSystem(this.context);
    // 载入设置并应用保存的主题（跟随系统/浅色/深色）
    try {
      settingsService.init(this.context);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to init settings. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');

      // Store initial window width for responsive layout（用密度换算 px→vp，避免已废弃的全局 px2vp）
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const widthVp = displayInfo.width / displayInfo.densityPixels;
        AppStorage.setOrCreate<number>('windowWidth', widthVp);
        hilog.info(DOMAIN, TAG, 'Window width: %{public}f vp', widthVp);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Failed to get display width');
      }
    });

    // Listen for window size changes
    windowStage.getMainWindow().then((win) => {
      try {
        win.setWindowPrivacyMode(true).catch((err: Error) => {
          hilog.error(DOMAIN, TAG, 'Failed to enable window privacy: %{public}s', err.message);
        });
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to enable window privacy');
      }
      win.on('windowSizeChange', (size: window.Size) => {
        const density = display.getDefaultDisplaySync().densityPixels;
        const widthVp = size.width / density;
        AppStorage.setOrCreate<number>('windowWidth', widthVp);
        hilog.info(DOMAIN, TAG, 'Window size changed: %{public}f vp', widthVp);
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: %{public}s', err.message);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Sensitive UI components subscribe to this event and mask revealed keys
    // before the app can remain visible in a recent-task snapshot.
    this.context.eventHub.emit(APP_CONSTANTS.APP_BACKGROUND_EVENT);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
