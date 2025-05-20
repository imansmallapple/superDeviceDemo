import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import Log from '../utils/Log';
import bundleManager from '@ohos.bundle.bundleManager';
import DeviceManager from '../utils/DeviceManager';

const permissions: Array<Permissions> = ['ohos.permission.DISTRIBUTED_DATASYNC', 'ohos.permission.ACCESS_SERVICE_DM'];

export default class EntryAbility extends UIAbility {
  storage: LocalStorage = new LocalStorage();
  want?: Want;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    DeviceManager.createDeviceManager();
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    checkPermissions(this.context);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}

async function checkPermissions(context: common.UIAbilityContext) {
  let grantStatus: abilityAccessCtrl.GrantStatus = await checkAccessToken();
  if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
    // Applying for the distributed data synchronization permission.
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(context, permissions).then((data) => {
      let grantStatus: Array<number> = data.authResults;
      let length: number = grantStatus.length;
      for (let i: number = 0; i < length; i++) {
        if (grantStatus[i] === 0) {
          Log.info('EntryAbility', `checkPermissions request permission ${permissions[i]} success`);
        } else {
          Log.error('EntryAbility',
            `checkPermissions request fail permission=${permissions[i]}, grantStatus=${grantStatus[i]}`);
          return;
        }
      }
    }).catch((err: Error) => {
      Log.error('EntryAbility',
        `checkPermissions request permissions failed, err=${JSON.stringify(err)}`);
    })
  }
}

async function checkAccessToken() {
  let atManager = abilityAccessCtrl.createAtManager();
  let tokenId: number = 0;
  try {
    let bundleInfo: bundleManager.BundleInfo = await bundleManager
      .getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
    tokenId = appInfo.accessTokenId;
  } catch (err) {
    Log.error('EntryAbility',
      `checkAccessToken Failed to get bundle info for self. err=${JSON.stringify(err)}`);
  }

  let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
  try {
    grantStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.DISTRIBUTED_DATASYNC');
  } catch (err) {
    Log.error('EntryAbility',
      `checkAccessToken Failed to check access token. err=${JSON.stringify(err)}`);
  }

  return grantStatus;
}