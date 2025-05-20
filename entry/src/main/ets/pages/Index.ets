import common from '@ohos.app.ability.common';
import distributedKVStore from '@ohos.data.distributedKVStore';
import deviceManager from '@ohos.distributedDeviceManager';
import DeviceManager from '../utils/DeviceManager'


let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  startFindingNearbyDevice(): void {
    DeviceManager.startDeviceDiscovery()
  }

  build() {
    Column() {
      Button('Find nearby Device')
        .onClick(() => {
          this.startFindingNearbyDevice()
        })
    }
    .width('100%')
    .height('100%')
  }
}