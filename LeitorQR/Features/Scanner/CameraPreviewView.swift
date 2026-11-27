import AVFoundation
import SwiftUI
import UIKit

/// AVCaptureVideoPreviewLayer 的 SwiftUI 包装。
/// Session 由 CameraScannerService 持有，这里只负责显示、「点击对焦」「双指缩放」的手势，
/// 以及把元数据坐标换算成屏幕坐标（取景框锁定动画要用）。
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    /// 点击回调：`viewPoint` 用于画对焦指示框，`devicePoint` 是 0…1 的归一化设备坐标。
    var onTap: ((CGPoint, CGPoint) -> Void)?
    /// 双指缩放：`.began` 时 scale 为 1，之后是相对开始时的比例。
    var onPinch: ((UIGestureRecognizer.State, CGFloat) -> Void)?
    /// 视图创建后回传自身，供服务做坐标换算。
    var onAttach: ((CameraPreviewUIView) -> Void)?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTap = onTap
        view.onPinch = onPinch
        onAttach?(view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.onTap = onTap
        uiView.onPinch = onPinch
    }
}

final class CameraPreviewUIView: UIView {

    var onTap: ((CGPoint, CGPoint) -> Void)?
    var onPinch: ((UIGestureRecognizer.State, CGFloat) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass 已固定为 AVCaptureVideoPreviewLayer，可安全强转。
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 元数据输出的归一化矩形 → 窗口坐标（与 SwiftUI `.global` 同一坐标系）。
    /// 必须在主线程调用。换算失败或矩形退化时返回 nil，调用方退回取景框自身位置。
    func windowRect(forMetadataRect rect: CGRect) -> CGRect? {
        guard window != nil else { return nil }
        let layerRect = previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
        guard layerRect.width > 8, layerRect.height > 8, layerRect.width.isFinite, layerRect.height.isFinite else {
            return nil
        }
        return convert(layerRect, to: nil)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        // 预览层是 aspectFill，必须用系统换算而不是简单按比例。
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onTap?(point, devicePoint)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        onPinch?(recognizer.state, recognizer.scale)
    }
}
