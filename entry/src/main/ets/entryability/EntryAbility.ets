import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
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
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
