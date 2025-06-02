# Super Device Demo

## Content table
1. [Description](#description)
2. [Pre permissions settings](#pre-permissions-settings)
3. [Device Pairing](#device-pairing)
4. [Data Sharing](#data-sharing)
5. [Create UI for Pairing and Sharing Data](#create-ui-for-pairing-and-sharing-data)
6. [Project Structure](#project-structure)

## Description
This demo showcases a simple implementation of cross-device data synchronization using the `distributedKVStore` module in OpenHarmony. After device pairing under the same network and PIN code verification, the sender device can push messages to the receiver device through a distributed key-value store. The receiver listens for data changes and updates its state accordingly.

## Pre Permissions settings
Before start, we need to make sure the application granted apporiate permissions to share data.

Under `module.json5` file, add the following code:
```ts
"requestPermissions": [
{
    "name": "ohos.permission.ACCESS_SERVICE_DM",
},
{
    "name": "ohos.permission.DISTRIBUTED_DATASYNC",
}
]
```

Under `entryability/EntryAbility.ets` file, make the following modification based on your project:
```ts
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
    this.want = want
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate')
    DeviceManager.createDeviceManager()
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.want = want

    if (this.want?.parameters?.messageList) {
      let messageList: string[] = JSON.parse((this.want.parameters.messageList) as string)
      this.storage.setOrCreate('messageList', messageList)
    } // You can adjust the global data to your project
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    if (this?.want?.parameters?.messageList) {
      let messageList: string[] = JSON.parse((this.want.parameters.shared_data) as string)
      this.storage.setOrCreate('messageList', messageList)
    } // You can adjust the global data to your project

    checkPermissions(this.context)

    windowStage.loadContent('pages/Index', this.storage, (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
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
```

## Device Pairing

This section describes how two devices establish a trusted relationship to enable cross-device data synchronization using `@ohos.distributedDeviceManager`.

### Overview

Before any data can be synchronized between devices, they must first be paired under a secure and trusted environment. This process involves:

1. **[Create Device manager instance](#1-create-device-manager-instance)**
2. **[Device discovery](#2-device-discovery)**
3. **[Bind target device](#3-bind-target-device)**

---

#### 1. Create Device Manager Instance

First step is to create a `DeviceManager` instance and implement some basic preprocessing: **register device state listener**, **get local device information**, **get available device list** and **initialize device list**. You can check the following code as reference:

```ts
import deviceManager from '@ohos.distributedDeviceManager'
import Log from './Log'
import common from '@ohos.app.ability.common'
import Want from '@ohos.app.ability.Want'
import { BusinessError } from '@ohos.base'

class DeviceManager {
  private static instance: DeviceManager | undefined = undefined
  private myDeviceManager?: deviceManager.DeviceManager
  private deviceList: deviceManager.DeviceBasicInfo[] = []
  private availableDeviceList: deviceManager.DeviceBasicInfo[] = []

  static getInstance(): DeviceManager {
    if (!DeviceManager.instance) {
      DeviceManager.instance = new DeviceManager()
    }
    return DeviceManager.instance;
  }

  async createDeviceManager() {
    if (this.myDeviceManager !== undefined) {
      Log.info('DeviceManager', 'DeviceManager already exists');
      return;
    }

    try {
      this.myDeviceManager = deviceManager.createDeviceManager("REPLACE WITH YOUR PACKAGE NAME");

      this.registerDeviceStateListener();
      this.getLocalDeviceInfo();
      this.getAvailableDeviceList();
      this.initDeviceList();
      Log.info('DeviceManager', 'device list', this.deviceList)
    } catch (error) {
      Log.error('DeviceManager', `createDeviceManager failed: ${JSON.stringify(error)}`);
    }
  }

  registerDeviceStateListener(): void {
    if (!this.myDeviceManager) {
      Log.error('DeviceManager', 'registerDeviceStateListener deviceManager has not initialized')
      return;
    }
    try {
      this.myDeviceManager.on('deviceStateChange', (data) => {
        if (!data) return;
        switch (data.action) {
          case deviceManager.DeviceStateChange.AVAILABLE:
            this.deviceOnline(data.device);
            break;
          case deviceManager.DeviceStateChange.UNAVAILABLE:
            this.deviceOffline(data.device);
            break;
        }
      });
    } catch (error) {
      Log.error('DeviceManager',
        `registerDeviceStateListener on('deviceStateChange') failed, error=${JSON.stringify(error)}`)
    }
  }

  getLocalDeviceInfo(): void {
    if (!this.myDeviceManager) return;

    try {
      Log.info('DeviceManager', `Local Device ID: ${this.myDeviceManager.getLocalDeviceId()}, Name: ${this.myDeviceManager.getLocalDeviceName()}, Type: ${this.myDeviceManager.getLocalDeviceType()
        .toString()}, Network ID:${this.myDeviceManager.getLocalDeviceNetworkId()}`);
    } catch (err) {
      Log.error('DeviceManager', `getLocalDeviceInfo failed: ${JSON.stringify(err)}`);
    }
  }

  getAvailableDeviceList(): void {
    if (!this.myDeviceManager) return;

    try {
      this.availableDeviceList = this.myDeviceManager.getAvailableDeviceListSync();
    } catch (err) {
      Log.error('DeviceManager', `getAvailableDeviceListSync failed: ${JSON.stringify(err)}`);
    }
  }

  initDeviceList(): void {
    this.deviceList = [];
    this.availableDeviceList.forEach(device => this.addToDeviceList(device));
    AppStorage.setOrCreate('deviceList', this.deviceList);
  }

  deviceOnline(device: deviceManager.DeviceBasicInfo): void {
    this.availableDeviceList.push(device);
    this.addToDeviceList(device);
  }

  deviceOffline(device: deviceManager.DeviceBasicInfo): void {
    this.availableDeviceList = this.availableDeviceList.filter(item => item.networkId !== device.networkId);
    this.deleteFromDeviceList(device);
  }

  addToDeviceList(device: deviceManager.DeviceBasicInfo): void {
    const index = this.deviceList.findIndex(d => d.deviceId === device.deviceId);
    if (index >= 0) {
      this.deviceList[index] = device;
    } else {
      this.deviceList.push(device);
    }
    AppStorage.setOrCreate('deviceList', this.deviceList);
  }

  deleteFromDeviceList(device: deviceManager.DeviceBasicInfo): void {
    this.deviceList = this.deviceList.filter(d => d.deviceId !== device.deviceId);
    AppStorage.setOrCreate('deviceList', this.deviceList);
  }
}
```

#### 2. Device Discovery

Create a method called `startDeviceDiscovery` for sender initiates device discovery:

```ts
  startDeviceDiscovery(): void {
    this.discoverList = [];
    this.initDeviceList();
    if (this.myDeviceManager === undefined) {
      Log.error('DeviceManager', 'startDeviceDiscovery deviceManager has not initialized');
      return;
    }

    try {
      this.stopDeviceDiscovery()

      this.myDeviceManager.startDiscovering(
        {
          discoverTargetType: 1 // default value is 1
        },
        {
          availableStatus: 0, // 0 stands for device offline
        }
      );
      this.isDiscovering = true;
      this.myDeviceManager.on('discoverSuccess', (data) => {
        if (data) {
          Log.info('DeviceManager', `Device found: ${JSON.stringify(data.device.deviceName)}`);
          this.deviceFound(data.device);
        } else {
          Log.warn('DeviceManager', 'Discovery success, but no device in data');
        }
      });

      this.myDeviceManager.on('discoverFailure', (data) => {
        Log.error('DeviceManager', `Device discovery failed: ${JSON.stringify(data)}`);
      });

    } catch (err) {
      Log.error('DeviceManager', `startDeviceDiscovery failed: ${JSON.stringify(err)}`);
    }
  }

    stopDeviceDiscovery(): void {
    if (this.isDiscovering) {
      Log.warn('DeviceManager', 'Discovery already in progress, skipping...');
      return;
    }

    if (!this.myDeviceManager) return;

    try {
      this.myDeviceManager.stopDiscovering();
      this.isDiscovering = false;
    } catch (err) {
      Log.error('DeviceManager', `stopDeviceDiscovery failed: ${JSON.stringify(err)}`);
    }
  }

    deviceFound(device: deviceManager.DeviceBasicInfo): void {
    if (!this.discoverList.find(d => d.deviceId === device.deviceId)) {
      this.discoverList.push(device);
      this.addToDeviceList(device);
    }
  }
```

#### 3. Bind target device
Create a method called `authenticateDevice` to bind target device, in this demo we are using `PINcode` verification way pairing the device:

```ts
  authenticateDevice(
    context: common.UIAbilityContext,
    device: deviceManager.DeviceBasicInfo,
    shared_list: string[]
  ): void {
    let tmpList = this.availableDeviceList.filter((item: deviceManager.DeviceBasicInfo) => device.deviceId === item.deviceId);
    if (tmpList.length > 0) {
      this.startAbility(context, device, shared_list);
      return;
    }

    if (this.myDeviceManager === undefined) {
      Log.error('RemoteDeviceModel', 'authenticateDevice deviceManager has not initialized');
      return;
    }

    let bindParam: Record<string, string | number> = {
      'bindType': 1, // 1 - The bind type is pin code. 2 - The bind type is QR code. 3 - The bind type is nfc. 4 - The bind type is no_interaction
      'targetPkgName': context.abilityInfo.bundleName,
      'appName': context.abilityInfo.applicationInfo.name,
    }

    try {
      AppStorage.setOrCreate('isSender', true)
      this.myDeviceManager.bindTarget(device.deviceId, bindParam, (err: BusinessError) => {
        if (err) {
          Log.error('Device Manager',
            `authenticateDevice error code=${err.code}, msg=${JSON.stringify(err.message)}`)
          return;
        } else {
          Log.info('DeviceManager', 'bindDevice success')
          this.boundDeviceList.push(device.deviceId);
          AppStorage.setOrCreate('boundDeviceList', this.boundDeviceList);
        }
      })
    } catch (error) {
      Log.error('Device Manager',
        `authenticateDevice failed error=${JSON.stringify(error)}`);
    }
  }

  unbindDevice(deviceId: string): void {
    if (this.myDeviceManager === undefined) {
      Log.error('RemoteDeviceModel', 'unbindDevice deviceManager has not initialized');
      return;
    }
    setTimeout(() => {
      try {
        this.myDeviceManager?.unbindTarget(deviceId)
        Log.info('RemoteDeviceModel', `Device unbind: ${deviceId}`)
      } catch (e) {
        Log.error('RemoteDeviceModel', `Failed to unbind: ${JSON.stringify(e)}`)
      }
    }, 0)
  }
```

## Data Sharing

This demo enables cross-device data sharing using OpenHarmony's `distributedKVStore` module. After devices are successfully paired, the sender can transmit data to the receiver in real-time.

---

### Architecture

- **Sender Device**: Calls `put()` and triggers `sync()` to push data.
- **Receiver Device**: Registers a `dataChange` listener to receive updates.

---

### Workflow

1. **Initialize KVStore**
   Both sender and receiver initialize a shared KVStore with the same store ID:

```ts
   const options = {
     createIfMissing: true,
     kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
     autoSync: true,
     securityLevel: distributedKVStore.SecurityLevel.S1
   };
```

kvManager.getKVStore('super_device_kvstore', options);

2. **Sender: Write and Sync**
   The sender writes data into the KVStore and pushes it to the receiver:
```ts
    kvStore.put('shared_text', 'Hello from sender');
    kvStore.sync([receiverDeviceId], distributedKVStore.SyncMode.PUSH_PULL);
```

3. **Receiver: Listen for Changes**
   The receiver listens for incoming updates using dataChange:
```ts
    kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, (data) => {
    data.insertEntries.forEach((entry) => {
        if (entry.key === 'shared_text') {
        this.receivedText = entry.value.value;
        }
      });
    });
```

The whole class of kvStoreModel is presented as following:

```ts
import distributedKVStore from '@ohos.data.distributedKVStore';
import common from '@ohos.app.ability.common';
import Log from './Log';

class KvStoreModel {
  kvManager?: distributedKVStore.KVManager;
  kvStore?: distributedKVStore.SingleKVStore;

  /**
   * Create a distributed key-value database.
   *
   * @param context Ability context.
   * @param callback Callback.
   */
  createKvStore(
    context: common.UIAbilityContext,
    callback: (data: distributedKVStore.ChangeNotification) => void
  ): void {
    if (this.kvStore !== undefined) {
      Log.info('KvStoreModel', 'createKvStore KVManager is exist');
      return;
    }

    let config: distributedKVStore.KVManagerConfig = {
      bundleName: context.abilityInfo.bundleName,
      context: context
    };
    try {
      this.kvManager = distributedKVStore.createKVManager(config);
    } catch (error) {
      Log.error('KvStoreModel',
        `createKvStore createKVManager failed, err=${JSON.stringify(error)}`);
      return;
    }

    let options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: false,
      backup: false,
      autoSync: true,
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };

    this.kvManager.getKVStore('super_device_kvstore', options).then((store: distributedKVStore.SingleKVStore) => {
      if (store === null) {
        Log.error('KvStoreModel', `createKvStore getKVStore store is null`);
        return;
      }
      this.kvStore = store;
      this.kvStore.enableSync(true).then(() => {
        Log.info('KvStoreModel', 'createKvStore enableSync success');
      }).catch((error: Error) => {
        Log.error('KvStoreModel',
          `createKvStore enableSync fail, error=${JSON.stringify(error)}`);
      });
      this.setDataChangeListener(callback);
    }).catch((error: Error) => {
      Log.error('getKVStore',
        `createKvStore getKVStore failed, error=${JSON.stringify(error)}`);
    })
  }

  /**
   * Add data to the distributed key-value database.
   *
   * @param key Store key name.
   * @param value Store value.
   */
  put(key: string, value: string, deviceId?: string): void {
    if (this.kvStore === undefined) {
      return;
    }

    this.kvStore.put(key, value).then(() => {
      Log.info('KvStoreModel', `kvStore.put key=${key} finished}`);

      if (deviceId) {
        try {
          this.kvStore!.sync([deviceId], distributedKVStore.SyncMode.PUSH_PULL)
          Log.info('KvStoreModel', `sync to ${deviceId} success`)
        } catch (err) {
          Log.error('KvStoreModel', `sync to ${deviceId} failed: ${JSON.stringify(err)},${err}`)
        }
      }

    }).catch((error: Error) => {
      Log.error('KvStoreModel',
        `kvStore.put key=${key} failed, error=${JSON.stringify(error)}`);
    });
  }

  /**
   * Set the data change listening function.
   *
   * @param callback Callback.
   */
  setDataChangeListener(callback: (data: distributedKVStore.ChangeNotification) => void): void {
    if (this.kvStore === undefined) {
      Log.error('KvStoreModel', 'setDataChangeListener kvStore is null')
      return
    }

    try {
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL,
        (data: distributedKVStore.ChangeNotification) => {
          if ((data.updateEntries.length > 0) || (data.insertEntries.length > 0)) {
            callback(data);
          }
          Log.info('kvStore','inside dataChange, data: ',data)
        });
    } catch (error) {
      Log.error('KvStoreModel',
        `setDataChangeListener on('dataChange') failed, err=${JSON.stringify(error)}`);
    }
  }

  /**
   * Remove the data change listener.
   */
  removeDataChangeListener(): void {
    if (this.kvStore === undefined) {
      return;
    }

    try {
      this.kvStore.off('dataChange');
    } catch (error) {
      Log.error('KvStoreModel',
        `removeDataChangeListener off('dataChange') failed, err=${JSON.stringify(error)}`);
    }
  }
}

export default KvStoreModel 
```

## Create UI for Pairing and Sharing Data

This section explains the user interface components responsible for discovering nearby devices, pairing with them, and sending/receiving messages using distributed key-value storage.

---

### 1. Device Discovery and Pairing

The UI provides a button to start discovering nearby devices using `DeviceManager.startDeviceDiscovery()`. When the user clicks **"Find nearby Device"**, a custom dialog (`DeviceListDialog`) is opened, listing all discovered devices.

```ts
Button('Find nearby Device')
  .onClick(() => {
    this.startFindingNearbyDevice()
    this.dialogController.open()
  })
```

Upon selecting a device, the app initiates pairing via:

```ts
DeviceManager.authenticateDevice(context, device, shared_list)
```

After a successful pairing, device IDs are stored using:

```ts
@StorageLink('RemoteConnectDeviceId') remoteConnectDeviceId: string = ''
@State connectedDeviceId: string = ''
```

### 2. Data Input and Sending
Once a connection is established, users can input text and send it to the paired device using distributedKVStore.

```ts
TextInput({ text: this.textInput, placeholder: 'Input your word..' })
  .onChange((value: string) => {
    this.textInput = value
  })

Button('Send')
  .onClick(() => {
    if (!this.connectedDeviceId || !this.textInput) return
    this.pushData(this.textInput)
  })
```

The pushData() method stores the message into a distributed key-value store and syncs it:

```ts
this.kvStoreModel.put('sync messageList', JSON.stringify(this.messageList))
```

### 3. Receiving Data
When data is synced from a remote device, the receiving device listens to dataChange events and updates the UI:

```ts
this.kvStoreModel.createKvStore(this.context, (data: distributedKVStore.ChangeNotification) => {
  data.insertEntries.forEach((entry) => {
    this.receivedList.push(entry.value.value as string)
  })
})
```

The messages are then rendered:

```ts
Text('receive message:')
ForEach(this.receivedList, (item: string) => {
  Text(item)
})
```

## Project Structure
Below is a simplified file structure of the project illustrating the key directories and files:

```markdown
/app-OniroNews
├── /entry
│   ├── oh-package.json5                  // Entry module package definition
│   └── /src
│       └── /main
│           ├── module.json5              // Entry module configuration
│           └── /ets
│               │  
│               ├── /view
│               │   └── CustomDialogComponents.ets                
│               │ 
│               ├── /entryability
│               │   └── EntryAbility.ets  // Main application ability
│               │ 
│               ├── /pages
│               │   └── Index.ets         
│               │            
│               └── /utils
│                   ├── Log.ts
│                   ├── DeviceManager.ets
│                   └── kvStoreUtil.ts
│
├── build-profile.json5                    
└── oh-package.json5                       
```
