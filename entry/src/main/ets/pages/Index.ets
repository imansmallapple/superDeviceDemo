import DeviceManager from '../utils/DeviceManager'
import DeviceListDialog from '../view/CustomDialogComponent';
import deviceManager from '@ohos.distributedDeviceManager'
import Log from '../utils/Log';
import common from '@ohos.app.ability.common';
import KvStoreModel from '../utils/kvStoreUtil';
import promptAction from '@ohos.promptAction';
import distributedKVStore from '@ohos.data.distributedKVStore';

let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  @StorageLink('deviceList') deviceList: deviceManager.DeviceBasicInfo[] = []
  @StorageLink('RemoteConnectDeviceId') remoteConnectDeviceId: string = ''
  @StorageLink('isSender') isSender: boolean = false
  @StorageLink('isReceiver') isReceiver: boolean = false
  @StorageLink('isPaired') isPaired: boolean = false
  @LocalStorageProp('messageList') messageList: string[] = [];
  @State connectedDeviceId: string = ''
  @State textInput: string = ''
  @State receivedText: string[] = []
  @State isLoading: boolean = false
  @State isAbleUnbind: boolean = false
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private kvStoreModel: KvStoreModel = new KvStoreModel();
  @State receivedList: string[] = []

  aboutToAppear() {
    // this.kvStoreModel.createKvStore(this.context, (data) => {
    //   Log.info('KvStore', 'KvStore onDataChange triggered')
    //   data.insertEntries.forEach((entry) => {
    //     Log.info('KvStore', `Key: ${entry.key}, Value: ${JSON.stringify(entry.value)}`)
    //     if (entry.key === 'shared_text') {
    //       try {
    //         let newData = JSON.parse((entry.value.value) as string) as string[]
    //         this.receivedText = [...newData]
    //         Log.info('KvStore', 'Updated receivedText: ' + this.receivedText)
    //       } catch (e) {
    //         Log.error('KvStore', 'Failed to parse shared_text: ' + JSON.stringify(e))
    //       }
    //     }
    //   })
    // })
    this.createKVStore()
    DeviceManager.clearDeviceList()
  }

  createKVStore(): void {
    this.kvStoreModel.createKvStore(this.context, (data: distributedKVStore.ChangeNotification) => {
      this.messageList = []
      if (data.insertEntries.length > 0) {
        data.updateEntries.forEach((entry) => {
          Log.info('kvStore', 'inside insert', entry.key, entry.value.type, entry.value.value)
          this.receivedList.push((entry.value.value) as string)
          Log.info('kvStore', this.receivedList)
        })
      }
      if (data.updateEntries.length > 0) {
        data.updateEntries.forEach((entry) => {
          Log.info('kvStore', 'inside update', entry.key, entry.value.type, entry.value.value)
          this.receivedList.push((entry.value.value) as string)
          Log.info('kvStore', this.receivedList)
        })
      }
      // this.receivedList.push(data.insertEntries.length > 0 ? (data.insertEntries) : data.updateEntries)
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
      param: this.messageList,
      connectedDeviceId: this.connectedDeviceId,
      isLoading: this.isLoading,
      isPaired: this.isPaired,
    })
  })

  // checkAbleUnbind() {
  //   if (this.connectDeviceId !== '') {
  //     this.isAbleUnbind = true
  //   } else {
  //     this.isAbleUnbind = false
  //   }
  // }

  startFindingNearbyDevice(): void {
    DeviceManager.startDeviceDiscovery()
  }

  onCancel(): void {
    DeviceManager.stopDeviceDiscovery()
  }

  pushData(data: string): void {
    Log.info('ConnectedDeviceId: ', this.connectedDeviceId)
    Log.info('ConnectedDeviceId data: ', data)
    this.messageList.push(data)
    this.kvStoreModel.put('sync messageList', JSON.stringify(this.messageList))
    // Log.info('ConnectedDeviceId shared_text: ', JSON.stringify(this.shared_data))
    // this.shared_data.push(data)
    // this.kvStoreModel.put('shared_text', JSON.stringify(this.shared_data), this.connectedDeviceId)
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
      Row() {
        Button('Find nearby Device')
          .onClick(() => {
            this.startFindingNearbyDevice()
            this.dialogController.open()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(`${this.isSender ? 'Sender' : 'Receiver'}`)
          .alignSelf(ItemAlign.Start)

        Text(`Paired: ${this.isPaired}`)
          .alignSelf(ItemAlign.End)
      }
      .width('100%')
      .zIndex(1)
      .justifyContent(FlexAlign.End)

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
      }
      if (this.connectedDeviceId !== '') {
        Button('Unbind')
          .onClick(() => {
            promptAction.showToast({ message: 'Unbind...' })
            setTimeout(() => {
              DeviceManager.unbindDevice(this.connectedDeviceId)
              this.connectedDeviceId = ''
              this.remoteConnectDeviceId = ''
            }, 100)
          })
      }
      Text('Connected device id: ' + this.remoteConnectDeviceId == '' ? this.connectedDeviceId : this.remoteConnectDeviceId)

      TextInput({ text: this.textInput, placeholder: 'Input your word..' })
        .onChange((value: string) => {
          this.textInput = value
        })

      Button('Send')
        .onClick(() => {
          if (!this.connectedDeviceId ? 0 : !this.remoteConnectDeviceId || !this.textInput) {
            Log.info('No device connected or text is empty!')
            return
          }

          if (this.textInput) {
            this.pushData(this.textInput)
            // this.kvStoreModel.put('shared_text', this.textInput, this.connectDeviceId)
          }
        })

      Text('Send message:')
      ForEach(this.messageList, (item: string) => {
        Text(item)
      })

      Text('receive message:')
      ForEach(this.receivedList, (item: string) => {
        Text(item)
      })

    }
    .width('100%')
    .height('100%')
  }
}