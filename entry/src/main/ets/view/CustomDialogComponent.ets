import common from '@ohos.app.ability.common'
import deviceManager from '@ohos.distributedDeviceManager'
import promptAction from '@ohos.promptAction'

@Extend(Text)
function ButtonTextStyle() {
  .fontColor("#007DFF")
  .fontSize(16)
  .fontWeight(500)
}

@CustomDialog
export default struct DeviceListDialog {
  controller?: CustomDialogController
  @Link deviceList: deviceManager.DeviceBasicInfo[]
  @Link param: string[]
  @State toConnectDeviceId: string = ''
  @Link connectedDeviceId: string
  @State selectedIndex: number = -1
  @State selectedDeviceName: string = ''
  @Link isLoading: boolean
  @Link isPaired: boolean
  cancel: () => void = () => {
  }
  startAbility: (context: common.UIAbilityContext, device: deviceManager.DeviceBasicInfo, textInput: string[]) => void
    = () => {
  }

  getDeviceInfo(index: number): string {
    if (this.deviceList.length == 0) {
      promptAction.showToast({
        message: 'No available device!'
      })
      return ''
    }

    if (this.deviceList.length == 0) {
      this.isLoading = true
    } else {
      this.isLoading = false
    }

    this.toConnectDeviceId = this.deviceList[index].deviceId

    return this.deviceList[index].deviceName
  }

  build() {
    Column() {
      Row() {
        Text('Select Device')
          .fontSize(20)
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontColor(Color.Black)
          .fontWeight(FontWeight.Bold)
      }
      .padding({
        left: 24,
        right: 24,
        top: 24
      })
      .height(56)

      List() {
        ForEach(this.deviceList, (item: deviceManager.DeviceBasicInfo, index: number) => {
          ListItem() {
            Column() {
              Row() {
                Row() {
                  Text(item.deviceName)
                    .fontSize(24)
                    .width('78%')
                    .fontColor(Color.Black)
                    .margin({ left: 16 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Start)
                }
                .justifyContent(FlexAlign.Start)

                if (index === this.selectedIndex) {
                  Image($r('app.media.icon'))
                    .width('8%')
                    .objectFit(ImageFit.Contain)
                } else {
                  Image($r('app.media.app_icon'))
                    .width('8%')
                    .objectFit(ImageFit.Contain)
                    .opacity(0.5)
                }
              }
              .height(56)
              .onClick(() => {
                this.selectedIndex = index
                this.selectedDeviceName = this.getDeviceInfo(index)
              })
              .padding({
                left: 24,
                right: 24
              })
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              if (index !== this.deviceList.length - 1) {
                Row() {
                  Divider()
                    .width('100%')
                    .height(1)
                    .opacity(0.1)
                }
                .padding({
                  left: 64,
                  right: 24
                })
                .width('100%')
              }
            }
          }
        }, (item: deviceManager.DeviceBasicInfo) => item.deviceId)
      }
      .width('100%')

      Row() {
        Column() {
          Text('Cancel')
            .ButtonTextStyle()
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.controller !== undefined) {
            this.controller.close()
          }
          this.cancel()
        })

        Divider()
          .vertical(true)
          .height(22)

        Column() {
          Text('Confirm')
            .ButtonTextStyle()
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .height(40)
        .onClick(() => {
          if (-1 === this.selectedIndex) {
            promptAction.showToast({
              message: 'Please select a device!'
            })
          } else {
            if (this.controller !== undefined) {
              this.controller.close()
            }
            this.startAbility(getContext(this) as common.UIAbilityContext, this.deviceList[this.selectedIndex], this.param)
            promptAction.showToast({
              message: `Device: ${this.selectedDeviceName} connected!`
            })
            this.connectedDeviceId = this.toConnectDeviceId
            this.isPaired = true
          }
        })
      }
      .backgroundColor(Color.White)
      .border({
        color: Color.White,
      })
    }
  }
}