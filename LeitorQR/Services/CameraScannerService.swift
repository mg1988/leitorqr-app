import AVFoundation
import Combine
import UIKit

/// 摄像头的可用性状态。
enum CameraAvailability: Equatable {
    case unknown          // 尚未决定权限
    case authorized
    case denied
    case restricted
    case unavailable      // 模拟器或设备无可用摄像头
}

/// 负责 AVCaptureSession 的全生命周期：配置、启停、Torch、前后台、去重。
///
/// 关键约束（PRD 5.2）：
/// - 整个 App 只创建一次 Session，不做"每次进页面 new 一个"。
/// - 命中一个码后自动暂停，等 UI 关闭结果再恢复，避免重复弹窗。
/// - 进入后台必须 stopRunning，回前台按当前页面状态恢复。
final class CameraScannerService: NSObject, ObservableObject {

    @Published private(set) var availability: CameraAvailability = .unknown
    @Published private(set) var isRunning = false
    @Published private(set) var isTorchAvailable = false
    @Published private(set) var isTorchOn = false
    @Published private(set) var lastErrorMessage: String?
    /// 变焦档位（显示倍率）。带超广角的机型是 [0.5, 1, 2]，其余 [1, 2]。
    @Published private(set) var zoomPresets: [CGFloat] = [1, 2]
    /// 当前显示倍率（相对广角镜头）。双指缩放时连续变化。
    @Published private(set) var displayZoom: CGFloat = 1
    /// 最近一次命中的码在**窗口坐标**里的外接矩形；多码时是并集。
    /// 在 `onDetect` 之前写入，取景框据此做「四角收拢贴合到码」的锁定动画。
    @Published private(set) var lastDetectionRect: CGRect?

    /// 命中一个或多个码时回调（主线程）。一帧里的多个码一次性返回，
    /// 由结果页用选择列表展示，不再只取第一个。
    var onDetect: (([ScanContent]) -> Void)?

    /// 预览视图（只在主线程读写）。用于把元数据坐标换算成屏幕坐标。
    weak var previewView: CameraPreviewUIView?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.leitorqr.camera.session")
    private let metadataQueue = DispatchQueue(label: "com.leitorqr.camera.metadata")
    private var isConfigured = false
    private var isActive = false
    private var isPaused = false
    private var lastPayload: String?
    private var lastPayloadDate = Date.distantPast
    private let dedupInterval: TimeInterval = 2.0
    private var observers: [NSObjectProtocol] = []
    /// 以下三项只在 sessionQueue 上读写。
    private var videoDevice: AVCaptureDevice?
    /// 「1×」对应的 `videoZoomFactor`。虚拟多摄设备里 1.0 是超广角，广角在切换点上。
    private var wideZoomFactor: CGFloat = 1
    private var pinchBaseFactor: CGFloat = 1

    override init() {
        super.init()
        availability = Self.currentAvailability()
        registerObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - 对外接口

    /// 页面出现时调用：按权限状态启动。
    func activate() {
        isActive = true

        // 没有可用摄像头（模拟器、无摄像头设备）时不请求权限：
        // 申请一个用不上的权限只会造成误解，UI 应直接走「从相册导入」的降级路径。
        guard Self.hasCameraDevice else {
            publish { $0.availability = .unavailable }
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            publish { $0.availability = .authorized }
            configureIfNeededAndStart()
        case .notDetermined:
            requestAccess()
        case .denied:
            publish { $0.availability = .denied }
        case .restricted:
            publish { $0.availability = .restricted }
        @unknown default:
            publish { $0.availability = .denied }
        }
    }

    /// 页面消失或切 Tab 时调用。
    func deactivate() {
        isActive = false
        setPaused(false)
        stop()
    }

    func restart() {
        guard availability == .authorized else {
            activate()
            return
        }
        setPaused(false)
        configureIfNeededAndStart()
    }

    func setPaused(_ paused: Bool) {
        metadataQueue.async { [weak self] in
            guard let self else { return }
            self.isPaused = paused
            if !paused {
                // 不要把 lastPayload 清空：关闭结果页时二维码很可能还贴在取景框里，
                // 清空会让同一个码立刻被再识别一次，历史里就会多出一条重复记录。
                // 这里只把去重窗口重置，关闭后 `dedupInterval` 内不再重复触发。
                self.lastPayloadDate = Date()
            }
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.session.inputs
                .compactMap({ $0 as? AVCaptureDeviceInput })
                .first?.device,
                device.hasTorch else { return }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                let turningOff = device.torchMode == .on
                if turningOff {
                    device.torchMode = .off
                } else {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                }
                self.publish { $0.isTorchOn = !turningOff }
            } catch {
                self.publish { $0.lastErrorMessage = L10n.Scanner.sessionError }
            }
        }
    }

    /// 外部（如权限设置页返回）刷新权限状态；刚拿到授权时要把 session 补起来。
    func refreshAuthorization() {
        let refreshed = Self.currentAvailability()
        publish { service in
            service.availability = refreshed
            if refreshed == .authorized, service.isActive {
                service.configureIfNeededAndStart()
            }
        }
    }

    /// 点击对焦 + 测光。`point` 是 0…1 的归一化设备坐标。
    /// 对焦失败不影响扫码主流程，因此静默处理。
    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.session.inputs
                    .compactMap({ $0 as? AVCaptureDeviceInput })
                    .first?.device else { return }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
            } catch {
                // 忽略：对焦是可选的体验优化，不应打断扫描。
            }
        }
    }

    // MARK: - 变焦

    /// 切到某个显示倍率（0.5 / 1 / 2）。用 `ramp` 平滑过渡，而不是一帧跳过去。
    func setZoom(_ display: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDevice else { return }
            let factor = self.clampedFactor(display * self.wideZoomFactor, device: device)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.ramp(toVideoZoomFactor: factor, withRate: 6)
            } catch {
                return
            }
            let shown = factor / self.wideZoomFactor
            self.publish { $0.displayZoom = shown }
        }
    }

    /// 双指缩放开始：记下当前倍率作为基准。
    func beginPinchZoom() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDevice else { return }
            self.pinchBaseFactor = device.videoZoomFactor
        }
    }

    /// 双指缩放进行中：`scale` 是手势相对开始时的比例。直接设值，跟手不带延迟。
    func updatePinchZoom(scale: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDevice else { return }
            let factor = self.clampedFactor(self.pinchBaseFactor * scale, device: device)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.videoZoomFactor = factor
            } catch {
                return
            }
            let shown = factor / self.wideZoomFactor
            self.publish { $0.displayZoom = shown }
        }
    }

    /// 上限压在广角的 8 倍：再往上数码变焦只剩噪点，扫码反而更难。
    private func clampedFactor(_ factor: CGFloat, device: AVCaptureDevice) -> CGFloat {
        let upper = min(device.maxAvailableVideoZoomFactor, wideZoomFactor * 8)
        return min(max(factor, device.minAvailableVideoZoomFactor), upper)
    }

    // MARK: - 权限

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            // completion 在任意队列，isActive 只在主线程读写，必须回到主线程再判断。
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.availability = granted ? .authorized : .denied
                if granted, self.isActive { self.configureIfNeededAndStart() }
            }
        }
    }

    private static func currentAvailability() -> CameraAvailability {
        guard hasCameraDevice else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    /// 模拟器没有摄像头硬件，`AVCaptureDevice.default` 也不会返回设备。
    private static var hasCameraDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    /// 优先选带超广角的虚拟多摄设备：可以切 0.5×，近距离扫小码时系统还会自动切微距。
    /// 没有的话依次退到双摄、单广角。
    private static func preferredBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .back
        )
        for type in types {
            if let device = discovery.devices.first(where: { $0.deviceType == type }) { return device }
        }
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Session

    private func configureIfNeededAndStart() {
        guard availability != .unavailable else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                guard self.configureSession() else {
                    // 配置失败（无可用设备、输入/输出加不进去）必须落到"不可用"。
                    // 只 return 不更新状态的话，UI 会永远停在"正在启动摄像头"。
                    self.publish { service in
                        service.availability = .unavailable
                        service.isRunning = false
                    }
                    return
                }
                self.isConfigured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            self.publish { service in
                service.isRunning = running
                if !running {
                    // startRunning() 没真正跑起来：与其空转，不如让用户走相册降级。
                    service.availability = .unavailable
                }
            }
        }
    }

    private func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.publish { $0.isRunning = false }
        }
    }

    /// 必须在 sessionQueue 上调用。返回是否配置成功。
    private func configureSession() -> Bool {
        guard let device = Self.preferredBackCamera() else {
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()

            session.beginConfiguration()
            session.sessionPreset = .high

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(input)

            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return false
            }
            session.addOutput(output)

            session.commitConfiguration()

            // availableMetadataObjectTypes 反映的是**已提交**配置：在 begin/commit 事务内
            // 读取可能得到空集；而 metadataObjectTypes 的 setter 遇到设备不支持的类型会抛
            // NSInvalidArgumentException。所以必须在 commit 之后过滤，且不能用 requested 兜底。
            let requested = BarcodeFormat.allCases.map(\.avMetadataType)
            let available = Set(output.availableMetadataObjectTypes)
            output.metadataObjectTypes = requested.filter { available.contains($0) }
            output.setMetadataObjectsDelegate(self, queue: metadataQueue)

            configureZoom(for: device)

            let torchAvailable = device.hasTorch
            publish { $0.isTorchAvailable = torchAvailable }
            return true
        } catch {
            publish { $0.lastErrorMessage = L10n.Scanner.sessionError }
            return false
        }
    }

    /// 算出「1×」对应的 zoomFactor，并把起始画面放在广角上（虚拟设备默认是超广角，扫码太远）。
    private func configureZoom(for device: AVCaptureDevice) {
        videoDevice = device
        let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        if hasUltraWide, let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            wideZoomFactor = CGFloat(truncating: switchOver)
        } else {
            wideZoomFactor = 1
        }

        var presets: [CGFloat] = hasUltraWide ? [0.5, 1, 2] : [1, 2]
        presets = presets.filter { $0 * wideZoomFactor <= device.maxAvailableVideoZoomFactor + 0.01 }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor(wideZoomFactor, device: device)
            device.unlockForConfiguration()
        } catch {
            // 设不上就停在设备默认倍率，扫码仍可用。
        }

        let shown = device.videoZoomFactor / wideZoomFactor
        let finalPresets = presets.count > 1 ? presets : []
        publish { service in
            service.zoomPresets = finalPresets
            service.displayZoom = shown
        }
    }

    // MARK: - 生命周期

    private func registerObservers() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        })

        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive, self.availability == .authorized else { return }
            self.configureIfNeededAndStart()
        })

        observers.append(center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // session 已经死了：不停下来并更新状态，UI 会一直停在「运行中」的黑屏。
            self.stop()
            self.publish { $0.lastErrorMessage = L10n.Scanner.sessionError }
        })

        // 来电、多任务等导致中断：结束后在活跃页面恢复。
        observers.append(center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive, self.availability == .authorized else { return }
            self.configureIfNeededAndStart()
        })
    }

    /// 统一在主线程序列上更新 @Published，避免后台线程发通知。
    private func publish(_ changes: @escaping (CameraScannerService) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            changes(self)
        }
    }
}
// MARK: - 元数据输出

extension CameraScannerService: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // 此处运行在 metadataQueue 上。先把这一帧所有码解析出来再去重，
        // 否则「一帧多码」只会拿到第一个。
        guard !isPaused else { return }

        var contents: [ScanContent] = []
        var seenInFrame = Set<String>()
        var unionBounds: CGRect?
        for case let object as AVMetadataMachineReadableCodeObject in metadataObjects {
            // AVFoundation 对无 ECI 段的 QR 按 Latin-1 逐字节解码，UTF-8/GBK 的
            // 中文会显示成拉丁乱码；这里统一恢复成正确文本。
            let payload = QRTextDecoder.decoded(object.stringValue ?? "")
            guard !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seenInFrame.insert(payload).inserted else { continue }
            unionBounds = unionBounds.map { $0.union(object.bounds) } ?? object.bounds
            contents.append(
                ScanContent(
                    rawValue: payload,
                    barcodeFormat: BarcodeFormat.from(avMetadataType: object.type.rawValue),
                    source: .camera
                )
            )
        }
        guard !contents.isEmpty else { return }

        // 跨帧去重仍按「最后一个 payload」判断；一帧里只要出现新码就放行。
        let now = Date()
        if contents.count == 1,
           contents[0].rawValue == lastPayload,
           now.timeIntervalSince(lastPayloadDate) < dedupInterval {
            return
        }
        lastPayload = contents.last?.rawValue
        lastPayloadDate = now
        isPaused = true

        let metadataRect = unionBounds
        publish { service in
            // 坐标换算要碰预览层，必须在主线程。先写矩形再回调，取景框才能在同一拍锁定。
            // `publish` 已在主队列执行，这里显式声明主线程隔离，满足 UIKit 的 @MainActor 要求。
            let windowRect: CGRect? = metadataRect.flatMap { rect in
                MainActor.assumeIsolated { service.previewView?.windowRect(forMetadataRect: rect) }
            }
            service.lastDetectionRect = windowRect
            service.onDetect?(contents)
        }
    }
}
