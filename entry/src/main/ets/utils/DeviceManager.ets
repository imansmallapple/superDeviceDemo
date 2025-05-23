import deviceManager from '@ohos.distributedDeviceManager'
import Log from './Log'
import common from '@ohos.app.ability.common'
import Want from '@ohos.app.ability.Want'

class DeviceManager {
  private static instance: DeviceManager | undefined = undefined
  private myDeviceManager?: deviceManager.DeviceManager
  private deviceList: deviceManager.DeviceBasicInfo[] = []
  private availableDeviceList: deviceManager.DeviceBasicInfo[] = []
  private discoverList: deviceManager.DeviceBasicInfo[] = []
  private isDiscovering: boolean = false

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
      this.myDeviceManager = deviceManager.createDeviceManager("com.example.superdevicedemo");

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

  startDeviceDiscovery(): void {
    this.discoverList = [];
    this.initDeviceList();
    if (this.myDeviceManager === undefined) {
      Log.error('DeviceManager', 'startDeviceDiscovery deviceManager has not initialized');
      return;
    }

    if (this.isDiscovering) {
      Log.warn('DeviceManager', 'Discovery already in progress, skipping...');
      return;
    }

    try {
      this.myDeviceManager.startDiscovering(
        {
          discoverTargetType: 1
        },
        {
          availableStatus: 1,
          authenticationStatus: 1,
          authorizationType: 1
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
      'bindType': 4,
      'targetPkgName':  context.abilityInfo.bundleName,
      'appName': context.abilityInfo.applicationInfo.name,
    }

    try {
      this.myDeviceManager.bindTarget(device.deviceId, bindParam, (err) => {
        if (err) {
          Log.error('Device Manager',
            `authenticateDevice error code=${err.code}, msg=${JSON.stringify(err.message)}`);
          return;
        }
      })
    } catch (error) {
      Log.error('Device Manager',
        `authenticateDevice failed error=${JSON.stringify(error)}`);
    }
  }

  startAbility(context: common.UIAbilityContext, device: deviceManager.DeviceBasicInfo, shared_list: string[]): void {
    let wantValue: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: 'EntryAbility',
      deviceId: device.deviceId,
      parameters: {
        shared_list: JSON.stringify(shared_list)
      }
    };

    context.startAbility(wantValue).then(() => {
      Log.info('RemoteDeviceModel', `startAbility finished wantValue=${JSON.stringify(wantValue)}`);
    }).catch((error: Error) => {
      Log.error('RemoteDeviceModel', `startAbility failed, error=${JSON.stringify(error)}`);
    })
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
}

export default DeviceManager.getInstance()