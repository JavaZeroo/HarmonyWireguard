import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { settingsService } from '../service/SettingsService';
import { APP_CONSTANTS } from '../common/Constants';
import { initializeDesignSystem } from '../common/DesignSystem';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private windowSizeChangeHandler: (size: window.Size) => void = (size: window.Size): void => {
    this.storeWindowWidth(size.width);
  };

  private storeWindowWidth(widthPx: number): void {
    try {
      const density = display.getDefaultDisplaySync().densityPixels;
      const widthVp = widthPx / density;
      AppStorage.setOrCreate<number>('windowWidth', widthVp);
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Window width: %{public}d vp', Math.round(widthVp));
    } catch (err) {
      hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'Failed to update window width');
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initializeDesignSystem(this.context);
    // 载入设置并应用保存的主题（跟随系统/浅色/深色）
    try {
      settingsService.init(this.context);
    } catch (err) {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to init settings. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // Seed responsive state before loading ArkUI content; the page's own area callback
    // will refine this value for floating and split-screen windows.
    try {
      this.storeWindowWidth(display.getDefaultDisplaySync().width);
    } catch (err) {
      hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'Failed to seed window width');
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(APP_CONSTANTS.DOMAIN, TAG,
          'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(APP_CONSTANTS.DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    windowStage.getMainWindow().then((win) => {
      this.mainWindow = win;
      try {
        win.setWindowPrivacyMode(true).catch((err: Error) => {
          hilog.error(APP_CONSTANTS.DOMAIN, TAG,
            'Failed to enable window privacy: %{public}s', err.message);
        });
      } catch (err) {
        hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to enable window privacy');
      }
      this.storeWindowWidth(win.getWindowProperties().windowRect.width);
      win.on('windowSizeChange', this.windowSizeChangeHandler);
    }).catch((err: Error) => {
      hilog.error(APP_CONSTANTS.DOMAIN, TAG, 'Failed to get main window: %{public}s', err.message);
    });
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== null) {
      try {
        this.mainWindow.off('windowSizeChange', this.windowSizeChangeHandler);
      } catch (err) {
        hilog.warn(APP_CONSTANTS.DOMAIN, TAG, 'Failed to remove window size listener');
      }
      this.mainWindow = null;
    }
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Sensitive UI components subscribe to this event and mask revealed keys
    // before the app can remain visible in a recent-task snapshot.
    this.context.eventHub.emit(APP_CONSTANTS.APP_BACKGROUND_EVENT);
    hilog.info(APP_CONSTANTS.DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
