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