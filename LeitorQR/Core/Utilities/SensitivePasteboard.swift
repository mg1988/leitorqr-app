import UIKit
import UniformTypeIdentifiers

/// 敏感内容（Wi-Fi 密码等）的剪贴板写入。
///
/// 直接 `UIPasteboard.general.string = xxx` 有两个问题：
/// 1. 内容会长期留在系统公共剪贴板，任何前台 App 都能读走；
/// 2. 会通过通用剪贴板同步到登录同一 iCloud 账号的其他设备（接力）。
///
/// 这里改为 `setItems` + `.localOnly`（不同步跨设备）+ 90 秒过期
/// （密码管理器类 App 的通行做法）。其他常规内容仍走普通写入，
/// 保留复制链接跨设备接力等正常体验。
enum SensitivePasteboard {

    /// 过期时间与主流密码管理器一致：够粘贴进系统设置/Wi-Fi，短到不被翻旧账。
    private static let expiration: TimeInterval = 90

    static func copy(_ value: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(expiration)
            ]
        )
    }
}
