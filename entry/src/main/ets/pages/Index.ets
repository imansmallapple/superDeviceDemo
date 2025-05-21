import DeviceManager from '../utils/DeviceManager'
import DeviceListDialog from '../view/CustomDialogComponent';
import deviceManager from '@ohos.distributedDeviceManager'


let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  @StorageLink('deviceList') deviceList: deviceManager.DeviceBasicInfo[] = []
  private dialogController: CustomDialogController = new CustomDialogController({
    builder: DeviceListDialog({
      deviceList: this.deviceList,
      cancel: this.onCancel
    })
  })

  startFindingNearbyDevice(): void {
    DeviceManager.startDeviceDiscovery()
  }

  onCancel(): void {
    DeviceManager.stopDeviceDiscovery()
  }

  build() {
    Column() {
      Button('Find nearby Device')
        .onClick(() => {
          this.startFindingNearbyDevice()
          this.dialogController.open()
        })
    }
    .width('100%')
    .height('100%')
  }
}