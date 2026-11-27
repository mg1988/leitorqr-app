import AudioToolbox
import UIKit

/// 识别结果的触觉 + 声音反馈。
///
/// 为什么用 `UINotificationFeedbackGenerator` 而不是 `UIImpactFeedbackGenerator`：
/// 扫码是"完成了一件事"，不是"按了一下按钮"，`success` 的语义更准，系统给的
/// 那一下也更饱满。相册导入同样走这里，用户在相册里点完不用看结果就知道成了。
///
/// 每次触发后重新 `prepare()`：Taptic Engine 从待机到出振需要几十毫秒，
/// 提前准备能明显压低延迟，边扫边连续识别时差别很明显。
///
/// 只有方法标 `@MainActor`（要碰 UIKit），枚举本身不隔离——`soundEnabledKey`
/// 需要被 `@AppStorage` 在类型作用域里读到，加在类型上会变成 actor 隔离常量。
enum ScanFeedback {

    /// 提示音开关（Definições 里可关，默认开）。
    static let soundEnabledKey = "scanSoundEnabled"

    private static let notification = UINotificationFeedbackGenerator()

    /// 系统提示音 `Tink`：短、轻、不刺鼻，是扫码场景里最不招人烦的一档。
    /// 用系统音而不是自带音频文件——省掉一份资源，也不存在音频会话被音乐 App 抢走的问题。
    private static let successSound: SystemSoundID = 1057

    /// 页面出现时预热一次，避免第一次识别的那一下偏软。
    @MainActor
    static func prepare() {
        notification.prepare()
    }

    /// 成功识别到码：触感 + 提示音。
    @MainActor
    static func detected() {
        notification.notificationOccurred(.success)
        notification.prepare()
        playSoundIfEnabled()
    }

    /// 识别失败（图片里没有码等）。只给触感，不出声——失败还"叮"一下很吵。
    @MainActor
    static func failed() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    @MainActor
    private static func playSoundIfEnabled() {
        // 没有这个 key 时按开启处理：首次安装就该有声音。
        let enabled = UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
        guard enabled else { return }
        AudioServicesPlaySystemSound(successSound)
    }
}
