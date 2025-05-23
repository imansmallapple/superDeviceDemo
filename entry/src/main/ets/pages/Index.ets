import DeviceManager from '../utils/DeviceManager'
import DeviceListDialog from '../view/CustomDialogComponent';
import deviceManager from '@ohos.distributedDeviceManager'
import Log from '../utils/Log';
import common from '@ohos.app.ability.common';
import KvStoreModel from '../utils/kvStoreUtil';

let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  @StorageLink('deviceList') deviceList: deviceManager.DeviceBasicInfo[] = []
  @LocalStorageProp('shared_data') shared_data: string[] = []
  @State connectDeviceId: string = ''
  @State textInput: string = ''
  @State receivedText: string[] = []
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private kvStoreModel: KvStoreModel = new KvStoreModel();

  aboutToAppear() {
    this.kvStoreModel.createKvStore(this.context, (data) => {
      data.insertEntries.forEach((entry) => {
        if (entry.key === 'shared_text') {
          this.receivedText = JSON.parse((entry.value.value) as string) as string[]
          Log.info('Received text: ' + this.receivedText)
        }
      })
    })
  }

  aboutToDisappear(): void {
    this.kvStoreModel.removeDataChangeListener()
  }

  private dialogController: CustomDialogController = new CustomDialogController({
    builder: DeviceListDialog({
      startAbility: this.startAbility,
      deviceList: this.deviceList,
      cancel: this.onCancel,
      param: this.shared_data,
      connectedDeviceId: this.connectDeviceId
    })
  })

  startFindingNearbyDevice(): void {
    DeviceManager.startDeviceDiscovery()
  }

  onCancel(): void {
    DeviceManager.stopDeviceDiscovery()
  }

  pushData(data: string): void {
    Log.info('ConnectedDeviceId: ', this.connectDeviceId)
    Log.info('ConnectedDeviceId data: ', data)
    Log.info('ConnectedDeviceId shared_text: ', JSON.stringify(this.shared_data))
    this.shared_data.push(data)
    this.kvStoreModel.put('shared_text', JSON.stringify(this.shared_data), this.connectDeviceId)
  }

  startAbility(
    context: common.UIAbilityContext,
    device: deviceManager.DeviceBasicInfo,
    shared_list: string[]
  ): void {
    DeviceManager.authenticateDevice(context, device, shared_list)
    DeviceManager.stopDeviceDiscovery()
  }

  build() {
    Column() {
      Button('Find nearby Device')
        .onClick(() => {
          this.startFindingNearbyDevice()
          this.dialogController.open()
        })

      TextInput({ text: this.textInput, placeholder: 'Input your word..' })
        .onChange((value: string) => {
          this.textInput = value
        })

      Button('Send')
        .onClick(() => {
          if (!this.connectDeviceId || !this.textInput) {
            Log.info('No device connected or text is empty!')
            return
          }

          if (this.textInput) {
            this.pushData(this.textInput)
            // this.kvStoreModel.put('shared_text', this.textInput, this.connectDeviceId)
          }
        })

      Text('Received message:' + this.receivedText)

      ForEach(this.receivedText, (item: string) => {
        Text(item)
      })
    }
    .width('100%')
    .height('100%')
  }
}