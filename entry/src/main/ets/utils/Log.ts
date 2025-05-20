import hilog from '@ohos.hilog';

export default class Log {
    private static readonly DOMAIN = 0x0230;
    private static readonly TAG: string = '[Voice]';
    public static readonly LEVEL_DEBUG = hilog.LogLevel.DEBUG;
    public static readonly LEVEL_INFO = hilog.LogLevel.INFO;
    public static readonly LEVEL_WARN = hilog.LogLevel.WARN;
    public static readonly LEVEL_ERROR = hilog.LogLevel.ERROR;
    public static readonly LEVEL_FATAL = hilog.LogLevel.FATAL;
    public static LOG_LEVEL = Log.LEVEL_DEBUG;

    public static debug(TAG: string, ...arg: Array<string | object>) {
        let message = ''
        arg.forEach(item=>{
            let msg = item
            if (typeof msg !== 'string') {
                msg = JSON.stringify(msg)
            }
            message += msg
        })
        if (this.LOG_LEVEL <= this.LEVEL_DEBUG) {
            hilog.debug(this.DOMAIN, this.TAG, "[" + TAG + "]: " + message);
        }
    }

    public static info(TAG: string, ...arg: Array<any>) {
        let message = ''
        arg.forEach(item=>{
            let msg = item
            if (typeof msg !== 'string') {
                msg = JSON.stringify(msg)
            }
            message += msg
        })
        if (this.LOG_LEVEL <= this.LEVEL_INFO) {
            hilog.info(this.DOMAIN, this.TAG, "[" + TAG + "]: " + message);
        }
    }

    public static warn(TAG: string, message: string | object) {
        if (typeof message !== 'string') {
            message = JSON.stringify(message)
        }
        if (this.LOG_LEVEL <= this.LEVEL_WARN) {
            hilog.warn(this.DOMAIN, this.TAG, "[" + TAG + "]: " + message);
        }
    }

    public static error(TAG: string, ...arg: Array<string | object>) {
        let message = ''
        arg.forEach(item=>{
            let msg = item
            if (typeof msg !== 'string') {
                msg = JSON.stringify(msg)
            }
            message += msg
        })
        if (this.LOG_LEVEL <= this.LEVEL_ERROR) {
            hilog.error(this.DOMAIN, this.TAG, "[" + TAG + "]: " + message);
        }
    }

    public static fatal(TAG: string, message: string | object) {
        if (typeof message !== 'string') {
            message = JSON.stringify(message)
        }
        if (this.LOG_LEVEL <= this.LEVEL_FATAL) {
            hilog.info(this.DOMAIN, this.TAG, "[" + TAG + "]: " + message);
        }
    }
}