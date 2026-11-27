import Combine
import PhotosUI
import SwiftUI
import UIKit

/// 一次识别产出的结果集合，用于 sheet 展示。
struct DetectionSheet: Identifiable {
    let id = UUID()
    let results: [ScanContent]
}

final class ScannerViewModel: ObservableObject {

    let camera = CameraScannerService()
    private let imageScanner = ImageScannerService()
    private var cancellables = Set<AnyCancellable>()

    @Published var sheet: DetectionSheet?
    @Published var isProcessing = false
    @Published var errorMessage: String?

    /// 命中结果统一回调（含相册）。由 View 负责写历史、播成功动画，
    /// 再回调 `showSheet(for:)` 把结果页推出来——先弹 sheet 会把动画完全盖住。
    var onDetected: (([ScanContent]) -> Void)?

    /// 相册导入失败等需要在页面上提示的错误。
    var onFailure: (() -> Void)?

    init() {
        // CameraScannerService 是独立的 ObservableObject。嵌套在 ViewModel 里时
        // SwiftUI 只会订阅 ViewModel 自己的 @Published，**不会**顺着 `model.camera`
        // 去订阅内层对象。不转发的话，isRunning / availability / isTorchOn 的变化
        // 全都不触发重绘——表现为摄像头已经在出画面，却永远停在"正在启动摄像头"。
        camera.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        camera.onDetect = { [weak self] contents in
            self?.present(contents)
        }
    }

    func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = L10n.Error.invalidImage
                onFailure?()
                return
            }
            let results = try await imageScanner.scan(image: image)
            guard !results.isEmpty else {
                // 图片里没有码：给出明确错误提示与失败触感。
                errorMessage = L10n.Scanner.importEmpty
                onFailure?()
                return
            }
            present(results)
        } catch let error as ImageScannerError {
            errorMessage = error.errorDescription
            onFailure?()
        } catch {
            errorMessage = L10n.Error.scanFailed
            onFailure?()
        }
    }

    /// 把结果页推出来。由 View 在成功动画播完之后调用。
    func showSheet(for results: [ScanContent]) {
        guard !results.isEmpty else { return }
        sheet = DetectionSheet(results: results)
    }

    private func present(_ results: [ScanContent]) {
        guard !results.isEmpty else { return }
        onDetected?(results)
    }

    #if DEBUG
    /// 仅 Debug：把一次伪造的命中送进**完整**的回调链路（和相机真人识别走同一条路），
    /// 用来验收「识别 → 写历史 → 弹结果页」。绕过 ViewModel 直接调 View 的方法是测不出接线问题的。
    func simulateDetect(_ content: ScanContent) {
        present([content])
    }

    /// 仅 Debug：一次注入多个码，验收一帧多码的选择列表。
    func simulateDetects(_ contents: [ScanContent]) {
        present(contents)
    }
    #endif
}
