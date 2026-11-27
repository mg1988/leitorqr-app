import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 扫描首页。打开即扫，权限、闪光灯、相册导入、变焦、异常状态全部在这一页收口。
///
/// 2026-11-27 第三版（第二版的整屏磨砂不是 iOS 26 液态玻璃，重做）：
/// - **画面全屏清晰**，玻璃只用在控件层：顶部两枚原生液态玻璃圆钮、提示胶囊、底部变焦胶囊。
///   iOS 26 走系统 `glassEffect`（不再叠黑色染色和手绘高光），框外只压一层很淡的黑。
/// - 顶部左手电、右相册；底部不放任何控件（变焦按钮已去掉，双指缩放仍可用）。扫描页不放 PRO 皇冠。
/// - 命中时取景框收拢、贴合到码的真实边框并转薄荷绿，同一拍触感；结果页弹出期间画面压暗，
///   关闭后取景框滑回原位。
/// - 没有激光扫描线、中心大对勾、全屏白闪；所有动画只播一次，支持「减弱动态效果」。
struct ScannerView: View {

    /// 只有当前被选中的 Tab 才允许占用摄像头；否则切换 Tab 后后台仍会采集。
    var isActive: Bool = true

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 扫描后自动处理：Wi-Fi 与网址独立开关，默认关闭。
    @AppStorage(ScanAutoActionSettings.wifiAutoConnectKey)
    private var wifiAutoConnect = ScanAutoActionSettings.wifiAutoConnectDefault
    @AppStorage(ScanAutoActionSettings.websiteAutoOpenKey)
    private var websiteAutoOpen = ScanAutoActionSettings.websiteAutoOpenDefault
    @AppStorage(ScanAutoActionSettings.linkAutoOpenKey)
    private var linkAutoOpen = ScanAutoActionSettings.linkAutoOpenDefault

    #if DEBUG
    /// `LEITORQR_AUTO_OPEN=1` 强制开启网址自动打开，验收跳过结果页直接开浏览器。
    private var effectiveWebsiteAutoOpen: Bool {
        DebugLaunchOptions.autoOpen ? true : websiteAutoOpen
    }
    private var effectiveWifiAutoConnect: Bool {
        DebugLaunchOptions.autoConnectWifi ? true : wifiAutoConnect
    }
    private var effectiveLinkAutoOpen: Bool {
        DebugLaunchOptions.autoOpen ? true : linkAutoOpen
    }
    #else
    private var effectiveWebsiteAutoOpen: Bool { websiteAutoOpen }
    private var effectiveWifiAutoConnect: Bool { wifiAutoConnect }
    private var effectiveLinkAutoOpen: Bool { linkAutoOpen }
    #endif

    @StateObject private var model = ScannerViewModel()
    /// 快捷指令「扫码连 Wi-Fi」的一次性状态。
    @ObservedObject private var shortcuts = ShortcutRouter.shared
    /// 快捷指令模式下连上之后，顶部提示一下连到了哪个网络。
    @State private var joinedSSID: String?
    @State private var joinedToastTask: Task<Void, Never>?
    @State private var pickedItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?
    @State private var focusTask: Task<Void, Never>?
    /// 相册导入是异步 Task，视图消失时必须取消，否则仍会弹结果页 / 写历史。
    @State private var importTask: Task<Void, Never>?
    /// 命中后的锁定态：四角贴合到码并转绿，结果页关闭后才解除。
    @State private var showSuccess = false
    /// 锁定目标（窗口坐标）。nil 时四角停在取景框自身位置。
    @State private var lockRect: CGRect?
    /// 取景框占位在窗口坐标里的位置，四角图层据此绘制。
    @State private var reticleFrame: CGRect = .zero
    @State private var detectTask: Task<Void, Never>?
    /// 仅 Debug：`LEITORQR_SIMULATE_SCAN` 只注入一次。
    @State private var didSimulateScan = false
    /// 仅 Debug 假手电筒用：模拟器无闪光灯，需要本地状态才能验收开启态。
    @State private var fakeTorchOn: Bool = {
        #if DEBUG
        return DebugLaunchOptions.fakeTorchStartsOn
        #else
        return false
        #endif
    }()

    // MARK: - 手电筒状态（真机走 CameraScannerService，Debug 可假开）

    private var showsTorch: Bool {
        #if DEBUG
        if DebugLaunchOptions.fakeTorch { return true }
        #endif
        return model.camera.isTorchAvailable
    }

    private var isTorchOn: Bool {
        #if DEBUG
        if DebugLaunchOptions.fakeTorch { return fakeTorchOn }
        #endif
        return model.camera.isTorchOn
    }

    private func toggleTorch() {
        #if DEBUG
        if DebugLaunchOptions.fakeTorch {
            fakeTorchOn.toggle()
            return
        }
        #endif
        model.camera.toggleTorch()
    }

    private var isCameraLive: Bool {
        mode == .fake || (model.camera.availability == .authorized && model.camera.isRunning)
    }

    /// 结果页弹出期间压暗、模糊取景画面，让注意力落到结果上。
    private var isDimmed: Bool { model.sheet != nil }

    /// 模拟器没有摄像头，正常会落到「相机不可用」。这个开关只用于验收玻璃控件。
    private var mode: PreviewMode { PreviewMode.current }

    enum PreviewMode {
        case real
        case fake

        static var current: PreviewMode {
            #if DEBUG
            return DebugLaunchOptions.fakeCamera ? .fake : .real
            #else
            return .real
            #endif
        }

        static var forcesScannerUI: Bool {
            #if DEBUG
            return DebugLaunchOptions.forceScannerUI
            #else
            return false
            #endif
        }
    }

    var body: some View {
        content
            // 必须先撑满，再挂背景：`.background` 的尺寸跟随内容，
            // 权限/异常页的内容只有一张卡片，不撑满的话背景只铺出中间一条。
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 全屏背景走 background 而不是 ZStack 子视图：子视图上的
            // ignoresSafeArea 会把整个 ZStack 撑到屏幕边缘，连带把 VStack
            // 里的控件也拖出安全区、压到 TabBar 下面。
            .background { screenBackdrop }
            .overlay {
                if model.isProcessing {
                    processingOverlay
                }
            }
            .onPreferenceChange(ReticleFrameKey.self) { frame in
                reticleFrame = frame
            }
            .onAppear {
                model.onDetected = handleDetected
                model.onFailure = { ScanFeedback.failed() }
                ScanFeedback.prepare()
                if isActive { model.camera.activate() }
                simulateScanIfNeeded()
            }
            .onDisappear {
                detectTask?.cancel()
                focusTask?.cancel()
                importTask?.cancel()
                model.camera.deactivate()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    model.camera.activate()
                } else {
                    model.camera.deactivate()
                }
            }
            .onChange(of: pickedItem) { _, newItem in
                guard newItem != nil else { return }
                importTask?.cancel()
                importTask = Task {
                    await model.handlePickedItem(newItem)
                    guard !Task.isCancelled else { return }
                    pickedItem = nil
                }
            }
            .onChange(of: shortcuts.isWiFiScanArmed) { _, armed in
                // 快捷指令进来时，收掉还开着的结果页，直接回到取景。
                if armed, model.sheet != nil { model.sheet = nil }
            }
            .onChange(of: scenePhase) { _, phase in
                // 「扫码连 Wi-Fi」只对这一次打开有效，切到后台就失效。
                if phase == .background { shortcuts.consumeWiFiScan() }
                guard phase == .active else { return }
                model.camera.refreshAuthorization()
                if mode == .fake, model.camera.availability == .unavailable { return }
                if model.camera.availability == .authorized {
                    model.camera.activate()
                }
            }
            .sheet(item: $model.sheet, onDismiss: {
                model.camera.setPaused(false)
                releaseLock()
                // 付费墙统一由 RootTabView 呈现：同一视图不能挂两个 sheet。
                // 等用户看完结果再谈订阅，也更符合「价值优先」。
                // 从快捷指令进来时不弹付费墙：用户是来连 Wi-Fi 的。
                guard isActive, !shortcuts.isWiFiScanArmed else { return }
                PaywallTriggerManager.shared.recordScanSuccess(isPremium: subscriptions.isPremium)
            }) { detection in
                if detection.results.count == 1, let first = detection.results.first {
                    ScanResultView(content: first, justScanned: true)
                } else {
                    ScanResultListView(results: detection.results)
                }
            }
            .alert(
                L10n.Common.error,
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }

    /// 镜片当前的位置：锁定时贴合到码（没有码的位置就原地收紧一圈），否则停在取景框占位上。
    private var lensTarget: CGRect {
        guard showSuccess else { return reticleFrame }
        if let lockRect { return lockRect }
        return reticleFrame.insetBy(dx: reticleFrame.width * 0.12, dy: reticleFrame.height * 0.12)
    }

    /// 取景框圆角：待机圆润，锁定到码上时收紧，贴合码的直角。
    private var lensCornerRadius: CGFloat {
        showSuccess ? 16 : 34
    }

    /// 取景框边长。
    private let lensSide: CGFloat = 256

    // MARK: - 页面分支

    /// 是否显示取景画面（含 Debug 强制分支）。
    private var showsCamera: Bool {
        switch model.camera.availability {
        case .unavailable:
            return PreviewMode.forcesScannerUI || mode == .fake
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

    @ViewBuilder
    private var content: some View {
        if showsCamera {
            cameraContent
        } else if model.camera.availability == .unavailable {
            unavailableScreen
        } else {
            permissionScreen
        }
    }

    /// 全屏背景层：取景画面 → 液态玻璃镜片层 → 结果页弹出时的景深；或权限/异常页的品牌底色。
    ///
    /// 镜片层放在 background 里、控件下面：磨砂玻璃不能盖住按钮。
    /// 这一层 `ignoresSafeArea` 后铺满整个窗口，原点就是窗口原点，所以镜片直接用窗口坐标画，
    /// 不需要 GeometryReader（它放在 `.background { }.ignoresSafeArea()` 里会形成尺寸反馈）。
    @ViewBuilder
    private var screenBackdrop: some View {
        if showsCamera {
            ZStack {
                if mode == .fake {
                    FakeCameraBackdrop()
                } else {
                    CameraPreviewView(
                        session: model.camera.session,
                        onTap: { viewPoint, devicePoint in
                            model.camera.focus(at: devicePoint)
                            showFocusIndicator(at: viewPoint)
                        },
                        onPinch: { state, scale in
                            switch state {
                            case .began: model.camera.beginPinchZoom()
                            case .changed: model.camera.updatePinchZoom(scale: scale)
                            default: break
                            }
                        },
                        onAttach: { view in
                            model.camera.previewView = view
                        }
                    )
                }

                ScannerViewfinder(
                    hole: lensTarget,
                    cornerRadius: lensCornerRadius,
                    isLocked: showSuccess
                )
                .opacity(reticleFrame == .zero ? 0 : 1)

                // 结果页弹出时只压暗、不磨砂：iOS 26 的 sheet 自己就是玻璃，
                // 背后保留真实画面，玻璃才有东西可折射。
                Color.black.opacity(0.32)
                .opacity(isDimmed ? 1 : 0)
                .animation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion), value: isDimmed)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        } else {
            statusBackdrop
        }
    }

    // MARK: - 相机画面

    /// 布局（2026-11-27 第二版）：
    /// ```
    ///  [手电]                   [相册]     ← 两枚玻璃圆钮，顶部左右对称
    ///
    ///  ░░░░░░ 深色磨砂玻璃 ░░░░░░░░░░░░
    ///  ░░░  ╭──────────────╮  ░░░░░░░
    ///  ░░░  │  清晰的镜片   │  ░░░░░░░    ← 只有这里是清楚的画面
    ///  ░░░  ╰──────────────╯  ░░░░░░░
    ///       对准二维码或条形码
    ///       自动识别，无需拍照
    ///
    ///                                      ← 底部不放控件（双指缩放仍可用）
    /// ```
    private var cameraContent: some View {
        ZStack {
            if !isCameraLive, mode == .real {
                connectingBadge
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: Theme.Spacing.m)
                lensArea
                Spacer(minLength: Theme.Spacing.m)
            }

            if let focusPoint {
                // 对焦点来自全屏坐标（预览层忽略安全区），这里同口径对齐。
                FocusIndicator()
                    .position(focusPoint)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            if let joinedSSID {
                VStack {
                    FeedbackToast(systemImage: "wifi", message: L10n.Scanner.wifiJoined(joinedSSID))
                        .padding(.top, 64)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: joinedSSID) { _, new in new != nil }
        // 相机页固定按深色界面渲染（和系统相机一样）：玻璃控件不随系统浅色模式变成白片，
        // 白色图标在任何画面上都清楚。只作用在这一层，结果 sheet 仍跟随系统外观。
        .environment(\.colorScheme, .dark)
    }

    /// 顶部：左手电、右相册，两枚同规格玻璃圆钮放进同一个玻璃容器。
    /// 扫描页不放 PRO 皇冠（用户 11-27 要求）：这一页只做扫码，升级入口留在其他页签。
    private var topBar: some View {
        GlassGroup(spacing: Theme.Spacing.s) {
            HStack {
                if showsTorch {
                    GlassCircleButton(
                        systemImage: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        tint: isTorchOn ? Theme.Palette.torch.opacity(0.22) : nil,
                        size: 46,
                        accessibilityLabel: L10n.Scanner.flashlight,
                        isOn: isTorchOn,
                        action: toggleTorch
                    )
                    .sensoryFeedback(.impact(weight: .light), trigger: isTorchOn)
                }

                Spacer(minLength: 0)

                PhotosGlassPicker(pickedItem: $pickedItem, style: .icon, iconSize: 46)
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, Theme.Spacing.xs)
    }

    /// 取景框占位 + 提示胶囊。取景框本身由背景里的 `ScannerViewfinder` 画（这里只报告位置），
    /// 这样锁定时取景框才能离开占位、贴到画面里任意位置的码上。
    private var lensArea: some View {
        VStack(spacing: Theme.Spacing.l) {
            Color.clear
                .frame(width: lensSide, height: lensSide)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ReticleFrameKey.self, value: proxy.frame(in: .global))
                    }
                }
                .accessibilityHidden(true)

            // 提示放进一枚玻璃胶囊：文字压在玻璃上，不直接压在画面上。
            HStack(spacing: 7) {
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Palette.scanLock)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                if shortcuts.isWiFiScanArmed && !showSuccess {
                    Image(systemName: "wifi")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                Text(showSuccess ? L10n.Scanner.detected : (shortcuts.isWiFiScanArmed ? L10n.Scanner.hintWiFi : L10n.Scanner.hint))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassSurface(RoundedRectangle(cornerRadius: 22, style: .continuous), tone: .dark)
            .frame(maxWidth: 300)
            .animation(Theme.Motion.success, value: showSuccess)
            .animation(Theme.Motion.smooth, value: shortcuts.isWiFiScanArmed)
        }
    }

    private var connectingBadge: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ProgressView()
                .tint(.white)
            Text(L10n.Scanner.connecting)
                .font(Theme.Typography.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .glassSurface(.capsule, tone: .dark)
    }

    // MARK: - 权限与异常

    private var statusBackdrop: some View {
        Theme.Palette.cameraBackdrop
            .ignoresSafeArea()
    }

    private var permissionScreen: some View {
        statusCard(
            icon: "camera.metering.unknown",
            title: L10n.Scanner.permissionTitle,
            message: L10n.Scanner.permissionMessage
        ) {
            GlassPrimaryButton(
                title: L10n.Scanner.permissionOpenSettings,
                systemImage: "gearshape",
                height: 48,
                action: openSystemSettings
            )

            PhotosGlassPicker(pickedItem: $pickedItem)
        }
    }

    private var unavailableScreen: some View {
        statusCard(
            icon: "video.slash",
            title: L10n.Scanner.unavailableTitle,
            message: L10n.Scanner.unavailableMessage
        ) {
            PhotosGlassPicker(pickedItem: $pickedItem)
        }
    }

    private func statusCard<Actions: View>(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.bottom, Theme.Spacing.xxs)

            Text(title)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.s) {
                actions()
            }
        }
        .padding(Theme.Spacing.l)
        .glassSurface(
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous),
            tone: .dark
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            HStack(spacing: Theme.Spacing.s) {
                ProgressView()
                    .tint(.white)
                Text(L10n.Scanner.processing)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .glassSurface(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous),
                tone: .dark
            )
        }
        .transition(.opacity)
    }

    // MARK: - 行为

    /// 识别成功的完整反馈链：触感 → 四角锁定到码 → 写历史 → 稍后弹结果页。
    ///
    /// 顺序很关键：结果页是 `.sheet`，一弹出来就会盖住半个取景画面。先弹 sheet
    /// 等于把锁定动画遮掉，所以这里留一小段让四角贴合完成，触感与视觉落在同一拍上。
    private func handleDetected(_ contents: [ScanContent]) {
        guard !contents.isEmpty else { return }

        ScanFeedback.detected()
        saveToHistory(contents)

        // 快捷指令「扫码连 Wi-Fi」：这一次扫到 Wi-Fi 码时无视设置开关，直接连接；用掉即失效。
        let viaShortcut = shortcuts.isWiFiScanArmed
            && contents.count == 1
            && contents.first?.type == .wifi
        if viaShortcut { shortcuts.consumeWiFiScan() }

        let decision = ScanAutoActionResolver.decide(
            contents: contents,
            wifiAutoConnect: effectiveWifiAutoConnect || viaShortcut,
            websiteAutoOpen: effectiveWebsiteAutoOpen,
            linkAutoOpen: effectiveLinkAutoOpen
        )

        // 只有相机命中才有「码在画面里的位置」；相册导入原地收紧即可。
        let fromCamera = contents.first?.source == .camera
        let target = fromCamera ? lockTarget(from: model.camera.lastDetectionRect) : nil

        detectTask?.cancel()
        withAnimation(Theme.Motion.resolve(Theme.Motion.success, reduceMotion: reduceMotion)) {
            lockRect = reduceMotion ? nil : target
            showSuccess = true
        }

        detectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: successHoldNanoseconds)
            guard !Task.isCancelled else { return }

            switch decision {
            case .showResults:
                // 锁定态保持到结果页关闭（onDismiss 里解除），四角再滑回取景框。
                model.showSheet(for: contents)
            case .autoOpenWebsite(let url):
                // 低风险网址：直接用系统浏览器打开，不再弹结果页。
                releaseLock()
                openURL(url)
            case .autoConnectWiFi(let network):
                // 连不上（无 entitlement、用户拒绝、不在范围）就回退到结果页，
                // 让用户看到密码和错误信息，不至于「扫了什么都没发生」。
                let result = await WiFiConnector.join(network)
                if result != .joined {
                    model.showSheet(for: contents)
                } else {
                    releaseLock()
                    showJoinedToast(network.ssid)
                }
            case .autoOpenSystemAction(let url):
                // 电话 / 短信 / 邮件 / 地图：交给对应系统 App。
                // 系统自身的确认弹窗仍是最后一道闸，这里不额外拦截。
                releaseLock()
                openURL(url)
            }
        }
    }

    /// 自动连上 Wi-Fi 后在顶部提示 2 秒。系统确认弹窗关掉以后，用户需要一个「成了」的结果。
    private func showJoinedToast(_ ssid: String) {
        joinedToastTask?.cancel()
        withAnimation(Theme.Motion.resolve(Theme.Motion.success, reduceMotion: reduceMotion)) {
            joinedSSID = ssid
        }
        joinedToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Theme.Motion.fade) { joinedSSID = nil }
        }
    }

    /// 码的外接矩形 → 四角的锁定目标：四周外扩一点，再保证不小于 88pt、不出屏幕。
    private func lockTarget(from detected: CGRect?) -> CGRect? {
        guard var rect = detected, rect.width.isFinite, rect.height.isFinite else { return nil }
        rect = rect.insetBy(dx: -12, dy: -12)
        let minSide: CGFloat = 88
        if rect.width < minSide { rect = rect.insetBy(dx: -(minSide - rect.width) / 2, dy: 0) }
        if rect.height < minSide { rect = rect.insetBy(dx: 0, dy: -(minSide - rect.height) / 2) }
        // 窗口拿不到时不裁剪（极少见），宁可贴歪一点也不丢掉锁定动画。
        guard let bounds = model.camera.previewView?.window?.bounds else { return rect }
        let screen = bounds.insetBy(dx: 8, dy: 8)
        let clipped = rect.intersection(screen)
        return clipped.isNull || clipped.width < 40 || clipped.height < 40 ? nil : clipped
    }

    /// 解除锁定：四角从码的位置平滑滑回取景框。
    private func releaseLock() {
        detectTask?.cancel()
        withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)) {
            showSuccess = false
            lockRect = nil
        }
    }

    /// 锁定后停留多久再弹结果页。0.5 秒：够看清四角贴合 + 转绿，又不至于让人觉得卡住。
    /// Debug 可用 `LEITORQR_SUCCESS_HOLD` 拉长，方便截图验收。
    private var successHoldNanoseconds: UInt64 {
        #if DEBUG
        if let hold = DebugLaunchOptions.successHoldMilliseconds {
            return hold * 1_000_000
        }
        #endif
        return reduceMotion ? 250_000_000 : 500_000_000
    }

    /// 写入历史。相机与相册共用这一条路径——扫到的码一定能在「Histórico」里找到，
    /// 免费版的条数上限由 `HistoryStore` 自己裁。
    ///
    /// 落盘失败必须让用户看到：静默失败会变成"扫了但历史里没有"的灵异问题。
    private func saveToHistory(_ contents: [ScanContent]) {
        let premium = subscriptions.isPremium
        var didFail = false
        for content in contents {
            let saved = HistoryStore.save(content, in: modelContext, isPremium: premium)
            didFail = didFail || !saved
        }
        if didFail {
            model.errorMessage = L10n.Result.saveFailed
        }
    }

    /// 仅 Debug：注入一次识别，用来验收锁定动画与写历史链路（模拟器没有摄像头）。
    private func simulateScanIfNeeded() {
        #if DEBUG
        guard !didSimulateScan, let raw = DebugLaunchOptions.simulatedScan else { return }
        didSimulateScan = true
        // `|||` 分隔可注入多个码，验收「一帧多码 → 选择列表」。
        // 不能用逗号：`geo:38.7223,-9.1393` 这种坐标本身就带逗号，会被拆成两个码。
        let payloads = raw.components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let contents = payloads.map {
            ScanContent(rawValue: $0, barcodeFormat: .qrCode, source: .camera)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            model.simulateDetects(contents)
        }
        #endif
    }

    private func showFocusIndicator(at point: CGPoint) {
        focusTask?.cancel()
        withAnimation(Theme.Motion.snappy) {
            focusPoint = point
        }
        focusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Theme.Motion.fade) {
                focusPoint = nil
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - 取景框位置

/// 取景框占位在窗口坐标里的位置。
private struct ReticleFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - 相册导入

/// 相册入口。两种形态共用一套挑选逻辑：
/// - `.icon`：扫描页右上角的玻璃圆钮（常态，不遮挡取景画面）。
/// - `.prominent`：相机不可用 / 权限被拒时的降级主按钮。
///
/// 用 `.photosPicker(isPresented:)` 而不是 `PhotosPicker` 直接包 Label，
/// 这样按钮本体仍是标准 `Button`，能吃到系统 `.glassProminent` 与 `GlassCircleButton`。
struct PhotosGlassPicker: View {

    enum Style {
        case icon
        case prominent
    }

    @Binding var pickedItem: PhotosPickerItem?
    var style: Style = .prominent
    var iconSize: CGFloat = 40

    @State private var isPresented = false

    var body: some View {
        Group {
            switch style {
            case .icon:
                GlassCircleButton(
                    systemImage: "photo.on.rectangle.angled",
                    size: iconSize,
                    accessibilityLabel: L10n.Scanner.importFromPhotos
                ) {
                    isPresented = true
                }
            case .prominent:
                GlassPrimaryButton(
                    title: L10n.Scanner.importFromPhotos,
                    systemImage: "photo.on.rectangle.angled"
                ) {
                    isPresented = true
                }
            }
        }
        .photosPicker(
            isPresented: $isPresented,
            selection: $pickedItem,
            matching: .images,
            photoLibrary: .shared()
        )
    }
}

// MARK: - 取景框

/// 取景框：画面保持全屏清晰（iOS 26 Liquid Glass 的原则——内容在下、玻璃只做控件层），
/// 框外只压一层很淡的黑（不磨砂），框角是沿圆角走的圆弧。
///
/// - 待机：停在取景框占位上，静止，没有任何循环动画。
/// - 锁定：框收拢、平移到码的外接矩形上，圆角收紧，框角转薄荷绿并带一圈柔光，框外再暗一档。
///
/// 这一层铺满窗口，挖孔直接用窗口坐标画；框角用 frame + position 摆放，与挖孔在同一个动画事务里插值。
struct ScannerViewfinder: View {
    var hole: CGRect
    var cornerRadius: CGFloat
    var isLocked: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(isLocked ? 0.34 : 0.16)
                .mask {
                    LensCutout(hole: hole, cornerRadius: cornerRadius)
                        .fill(style: FillStyle(eoFill: true))
                }

            LensCorners(cornerRadius: cornerRadius, lineWidth: 4.5)
                .stroke(
                    isLocked ? Theme.Palette.scanLock : Color.white,
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(
                    color: isLocked ? Theme.Palette.scanLock.opacity(0.6) : .black.opacity(0.3),
                    radius: isLocked ? 12 : 4
                )
                .frame(width: max(hole.width + 8, 1), height: max(hole.height + 8, 1))
                .position(x: hole.midX, y: hole.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 整个矩形 + 镜片圆角矩形；配 even-odd 填充就是「挖了一个洞的玻璃」。
/// `hole` 和圆角都可动画，锁定时洞平滑地收拢到码上。
struct LensCutout: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<CGRect.AnimatableData, CGFloat> {
        get { AnimatablePair(hole.animatableData, cornerRadius) }
        set {
            hole.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        guard hole.width > 1, hole.height > 1 else { return path }
        path.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}

/// 四个圆弧取景角：每个角沿着圆角弧线走，再往两边各伸出一段直线。
/// 线宽的一半向外让出，四角刚好压在镜片高光边外侧。
struct LensCorners: Shape {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat = 4

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = lineWidth / 2
        let r0 = rect.insetBy(dx: inset, dy: inset)
        let side = min(r0.width, r0.height)
        guard side > 4 else { return path }
        let radius = min(cornerRadius + inset, side / 2)
        let leg = min(side * 0.14, 30)
        let x0 = r0.minX, y0 = r0.minY, x1 = r0.maxX, y1 = r0.maxY

        // 左上
        path.move(to: CGPoint(x: x0, y: y0 + radius + leg))
        path.addLine(to: CGPoint(x: x0, y: y0 + radius))
        path.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x0 + radius, y: y0), radius: radius)
        path.addLine(to: CGPoint(x: x0 + radius + leg, y: y0))

        // 右上
        path.move(to: CGPoint(x: x1 - radius - leg, y: y0))
        path.addLine(to: CGPoint(x: x1 - radius, y: y0))
        path.addArc(tangent1End: CGPoint(x: x1, y: y0), tangent2End: CGPoint(x: x1, y: y0 + radius), radius: radius)
        path.addLine(to: CGPoint(x: x1, y: y0 + radius + leg))

        // 右下
        path.move(to: CGPoint(x: x1, y: y1 - radius - leg))
        path.addLine(to: CGPoint(x: x1, y: y1 - radius))
        path.addArc(tangent1End: CGPoint(x: x1, y: y1), tangent2End: CGPoint(x: x1 - radius, y: y1), radius: radius)
        path.addLine(to: CGPoint(x: x1 - radius - leg, y: y1))

        // 左下
        path.move(to: CGPoint(x: x0 + radius + leg, y: y1))
        path.addLine(to: CGPoint(x: x0 + radius, y: y1))
        path.addArc(tangent1End: CGPoint(x: x0, y: y1), tangent2End: CGPoint(x: x0, y: y1 - radius), radius: radius)
        path.addLine(to: CGPoint(x: x0, y: y1 - radius - leg))

        return path
    }
}

/// 点击对焦的短暂指示框。
struct FocusIndicator: View {
    @State private var scale: CGFloat = 1.35

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: 74, height: 74)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(Theme.Motion.success) {
                    scale = 1
                }
            }
    }
}

/// 仅在 Debug 的 `LEITORQR_FAKE_CAMERA=1` 下使用的假取景画面。
/// 模拟器没有摄像头，用它来验收玻璃控件的折射、对比度与布局。
/// 有暖色块与深浅分区，才能看出玻璃有没有把背景"吃掉"。
///
/// 注意：这里刻意**不用 GeometryReader**。它放进 `.background { }.ignoresSafeArea()`
/// 里会形成尺寸反馈，把主线程卡在反复布局上（表现为定时器不触发、动画定格）。
struct FakeCameraBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x2B3A4A),
                    Color(hex: 0x4A5A65),
                    Color(hex: 0x1C2229)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: 0xE8B06A).opacity(0.75))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -110, y: -280)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: 0x7FA8C9).opacity(0.55))
                .frame(width: 340, height: 240)
                .blur(radius: 50)
                .offset(x: 90, y: 120)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 360, height: 90)
                .blur(radius: 40)
                .offset(y: 380)
        }
    }
}

#Preview {
    ScannerView(isActive: true)
        .environmentObject(SubscriptionManager())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
