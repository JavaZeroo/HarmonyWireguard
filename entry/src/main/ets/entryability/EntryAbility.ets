import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import display from '@ohos.display';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // Store initial window width for responsive layout
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const widthVp = px2vp(displayInfo.width);
        AppStorage.setOrCreate<number>('windowWidth', widthVp);
        hilog.info(DOMAIN, 'testTag', 'Window width: %{public}f vp', widthVp);
      } catch (e) {
        hilog.warn(DOMAIN, 'testTag', 'Failed to get display width');
      }
    });

    // Listen for window size changes
    windowStage.getMainWindow().then((win) => {
      win.on('windowSizeChange', (size: window.Size) => {
        const widthVp = px2vp(size.width);
        AppStorage.setOrCreate<number>('windowWidth', widthVp);
        hilog.info(DOMAIN, 'testTag', 'Window size changed: %{public}f vp', widthVp);
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to get main window: %{public}s', err.message);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
