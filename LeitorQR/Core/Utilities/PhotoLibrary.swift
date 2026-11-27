import Photos
import UIKit

/// 存相册。创建页与历史详情共用同一段逻辑：
/// 只申请 `addOnly` 权限（不需要读你整本相册），失败一律回调用 false 交给 UI 提示。
enum PhotoLibrary {

    static func save(_ image: UIImage, completion: @escaping @MainActor (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in completion(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in completion(success) }
            }
        }
    }
}
