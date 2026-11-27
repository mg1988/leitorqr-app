import SwiftData
import SwiftUI

/// 四个 Tab 的根容器。默认进入「Ler」，扫码优先，不做启动拦截。
/// 用系统 TabView；付费墙是唯一的全局 fullScreenCover 覆盖层。
struct RootTabView: View {

    enum Tab: String, Hashable, CaseIterable, Identifiable {
        case scan
        case create
        case history
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scan: return L10n.Tab.scan
            case .create: return L10n.Tab.create
            case .history: return L10n.Tab.history
            case .settings: return L10n.Tab.settings
            }
        }

        var icon: String {
            switch self {
            case .scan: return "qrcode.viewfinder"
            case .create: return "qrcode"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw: String = AppAppearance.system.rawValue
    @State private var selectedTab: Tab = RootTabView.initialTab
    /// 付费墙全项目只有一处呈现（下面的 fullScreenCover）。
    /// 页面里再挂 sheet 会造成两个 presentation 互相吞掉、结果页消失、相机永久暂停。
    @ObservedObject private var paywallTrigger = PaywallTriggerManager.shared
    @ObservedObject private var proPortal = ProPortal.shared
    @ObservedObject private var language = LanguageManager.shared
    @State private var hasCheckedColdLaunch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 首次安装盖在 TabView 上的一层：先是引导，最后一步直接切到付费墙（同一层里切换，
    /// 不先露出主页再弹）。这一层在的时候扫码页不启动相机：系统相机权限框要等用户真正看到扫码页才弹。
    @State private var launchOverlay: LaunchOverlay? = RootTabView.shouldShowOnboarding ? .onboarding : nil

    private enum LaunchOverlay {
        case onboarding
        case paywall
    }
    #if DEBUG
    @State private var showLanguagePicker = false
    #endif

    private var currentColorScheme: ColorScheme? {
        AppAppearance(rawValue: appearanceRaw)?.colorScheme
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(isActive: selectedTab == .scan && launchOverlay == nil)
                .tabItem {
                    Label(Tab.scan.title, systemImage: Tab.scan.icon)
                }
                .tag(Tab.scan)

            CreateLandingView()
                .tabItem {
                    Label(Tab.create.title, systemImage: Tab.create.icon)
                }
                .tag(Tab.create)

            HistoryView()
                .tabItem {
                    Label(Tab.history.title, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(Theme.Palette.primary)
        .preferredColorScheme(currentColorScheme)
        // 引导 + 付费墙盖在 TabView 上（overlay），不用 fullScreenCover：下面已经挂着付费墙的
        // fullScreenCover，同一视图上两个全屏 presentation 会互相吞掉。
        // 引导 → 付费墙：引导轻微缩小淡出，付费墙淡入并播自己的依次入场；
        // 付费墙关掉：整层淡出并轻微放大，这时才露出后面的扫码页。
        .overlay {
            ZStack {
                switch launchOverlay {
                case .onboarding:
                    OnboardingView(onFinish: finishOnboarding)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.combined(with: .scale(scale: 0.96))
                                )
                        )
                case .paywall:
                    PaywallView(
                        showsCloseButton: true,
                        triggerReason: .onboarding,
                        onClose: closeOnboardingPaywall
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                case nil:
                    EmptyView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToScanTab)) { _ in
            selectedTab = .scan
        }
        .fullScreenCover(isPresented: $paywallTrigger.isPaywallPresented) {
            NavigationStack {
                PaywallView(showsCloseButton: true, triggerReason: paywallTrigger.triggerReason)
            }
        }
        // 已订阅用户点页签右上角皇冠 → 订阅管理（可取消、可看下次续费日）。
        // 未订阅会走上面的付费墙，所以这里只处理「已订阅」这一支。
        .sheet(isPresented: $proPortal.isSubscriptionPresented) {
            NavigationStack {
                SubscriptionCenterView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.Common.close) {
                                proPortal.isSubscriptionPresented = false
                            }
                        }
                    }
            }
        }
        // 冷启动付费墙现在要两个前置：订阅刷新完成 + 本进程首次价值时刻（完整扫码/制码）。
        // 这里只登记「刷新完成」这一半；价值时刻由 PaywallTriggerManager 在扫码/制码事件里登记。
        // 不用固定 350ms：Product.products / subscription.status 是网络请求，
        // 固定延时会把尚未确定的 .unknown 当成「未订阅」，已付费用户每次都被弹付费墙。
        .onChange(of: subscriptions.hasCompletedInitialRefresh) { _, ready in
            guard ready, !hasCheckedColdLaunch else { return }
            hasCheckedColdLaunch = true
            #if DEBUG
            // 截图 / 自动化跳过付费墙；强制显示引导（LEITORQR_ONBOARDING=1）时放行，才能验收引导后的付费墙。
            if DebugLaunchOptions.isAutomation, !DebugLaunchOptions.forceOnboarding { return }
            #endif
            paywallTrigger.markSubscriptionRefreshCompleted(isPremium: subscriptions.isPremium)
        }
        .modifier(DebugLaunchModifier())
        #if DEBUG
        .fullScreenCover(isPresented: $showLanguagePicker) {
            NavigationStack { LanguageSelectionView() }
        }
        .onAppear {
            if DebugLaunchOptions.openLanguage { showLanguagePicker = true }
            if DebugLaunchOptions.openCrown {
                ProPortal.shared.openCrown(isPremium: subscriptions.isPremium)
            }
            if DebugLaunchOptions.shortcutWiFi {
                ShortcutRouter.shared.armWiFiScan()
            }
        }
        #endif
        // App 内选了阿拉伯语 / 希伯来语：整页镜像；日期、数字按所选语言格式化。
        // 二维码、条形码图片本身不会被镜像（Image 默认不随书写方向翻转）。
        .environment(\.layoutDirection, language.layoutDirection)
        .environment(\.locale, language.locale)
        // 语言切换后重建整棵视图树：L10n 是计算属性，重建时全部重新读取新 Bundle。
        .id(language.revision)
    }

    private static var shouldShowOnboarding: Bool {
        #if DEBUG
        // LEITORQR_ONBOARDING=1 强制显示；其他截图 / 自动化参数一律跳过，免得每张截图都拍到引导。
        if DebugLaunchOptions.forceOnboarding { return true }
        if DebugLaunchOptions.isAutomation { return false }
        #endif
        return !UserDefaults.standard.bool(forKey: OnboardingView.completedKey)
    }

    /// 引导结束：在同一层直接切到付费墙。只有「已经确认是会员」才跳过，直接进扫码页。
    ///
    /// 11-27 修：上一版要求订阅状态先刷新完才弹——真机上商品 / 权益请求要几秒，
    /// 用户在引导里点「跳过」往往比它快，结果首次安装一次付费墙都看不到。
    /// 现在不等：状态还没回来也先弹；回来发现其实是会员（重装后恢复买断 / 测试环境里买过），
    /// 付费墙原地变成「已解锁」状态，由用户点「继续」离开——不再自己跳走（11-27 用户反馈：
    /// 「啥也没干就跳到首页」就是之前的自动收起）。
    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: OnboardingView.completedKey)
        selectedTab = .scan
        let knownPremium = subscriptions.hasCompletedInitialRefresh && subscriptions.isPremium
        if !knownPremium {
            paywallTrigger.noteOnboardingPaywallShown()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.4)) {
                launchOverlay = .paywall
            }
        } else {
            dismissLaunchOverlay()
        }
    }

    private func closeOnboardingPaywall(purchased: Bool) {
        if !purchased {
            paywallTrigger.recordOnboardingPaywallDismissed()
        }
        dismissLaunchOverlay()
    }

    private func dismissLaunchOverlay() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.45)) {
            launchOverlay = nil
        }
    }

    private static var initialTab: Tab {
        #if DEBUG
        if let raw = DebugLaunchOptions.startTab, let tab = Tab(rawValue: raw) {
            return tab
        }
        #endif
        return .scan
    }
}

// MARK: - Debug 启动覆盖页（Release 构建为空实现）

private struct DebugLaunchModifier: ViewModifier {
    #if DEBUG
    @State private var overlay: DebugOverlay?

    private var debugPaywallReason: PaywallTriggerManager.TriggerReason? {
        switch DebugLaunchOptions.paywallReason {
        case "scan": return .postAha
        case "limit": return .usageLimit
        case "feature": return .featureGate("template")
        case "onboarding": return .onboarding
        default: return nil
        }
    }
    #endif

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .fullScreenCover(item: $overlay) { screen in
                screenContent(for: screen)
            }
            .onAppear {
                guard let raw = DebugLaunchOptions.overlayScreen,
                      let screen = DebugOverlay(rawValue: raw) else { return }
                overlay = screen
            }
        #else
        content
        #endif
    }

    #if DEBUG
    @ViewBuilder
    private func screenContent(for screen: DebugOverlay) -> some View {
        switch screen {
        case .paywall:
            NavigationStack {
                PaywallView(triggerReason: debugPaywallReason)
            }
        case .subscription:
            NavigationStack { SubscriptionCenterView() }
        case .result:
            NavigationStack {
                ScanResultView(
                    content: ScanContent(
                        rawValue: DebugLaunchOptions.resultPayload,
                        barcodeFormat: .qrCode,
                        source: .camera
                    )
                )
            }
        case .privacy:
            NavigationStack { LegalDocumentView(type: .privacy, isModal: true) }
        case .terms:
            NavigationStack { LegalDocumentView(type: .terms, isModal: true) }
        case .security:
            NavigationStack { SecurityCenterView() }
        case .riskHistory:
            NavigationStack { RiskHistoryView() }
        case .whitelist:
            NavigationStack { WhitelistView() }
        case .batchRisk:
            NavigationStack { BatchRiskScanView() }
        case .settings:
            SettingsView()
        }
    }
    #endif
}

#if DEBUG
private enum DebugOverlay: String, Identifiable {
    case paywall
    case subscription
    case result
    case privacy
    case terms
    case security
    case riskHistory
    case whitelist
    case batchRisk
    case settings

    var id: String { rawValue }
}
#endif

#Preview {
    RootTabView()
        .environmentObject(SubscriptionManager())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}

extension Notification.Name {
    static let switchToScanTab = Notification.Name("com.leitorqr.switchToScanTab")
}

// MARK: - 首次启动引导

/// 首次安装的三页引导（11-27）：扫码 → 生成 → 隐私（顺带为下一步的相机权限做铺垫）。
///
/// - 每页上半部分是用 SwiftUI 现画的插画，用的是 App 自己的渲染器和配色，所见即所得；不用位图。
/// - 插画动画只在第一次翻到那一页时播一次，播完停在终态；不循环。减弱动态效果时直接显示终态。
/// - 纯色背景、无渐变；主按钮 iOS 26 原生液态玻璃（品牌蓝），低版本实心胶囊。
/// - 右上角「跳过」直接结束引导；最后一页按钮「开始扫码」结束后回到扫码页，这时才弹系统相机权限框。
struct OnboardingView: View {

    static let completedKey = "onboarding.completed.v1"

    let onFinish: () -> Void

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.Onboarding.skip, action: onFinish)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .opacity(page < lastPage ? 1 : 0)
                    .disabled(page >= lastPage)
                    .accessibilityHidden(page >= lastPage)
            }
            .frame(height: 44)
            .padding(.horizontal, Theme.Spacing.pageMargin)

            TabView(selection: $page) {
                OnboardingPage(
                    isCurrent: page == 0,
                    title: L10n.Onboarding.scanTitle,
                    message: L10n.Onboarding.scanBody
                ) {
                    OnboardingScanArt(isCurrent: page == 0)
                }
                .tag(0)

                OnboardingPage(
                    isCurrent: page == 1,
                    title: L10n.Onboarding.createTitle,
                    message: L10n.Onboarding.createBody
                ) {
                    OnboardingCreateArt(isCurrent: page == 1)
                }
                .tag(1)

                OnboardingPage(
                    isCurrent: page == 2,
                    title: L10n.Onboarding.privacyTitle,
                    message: L10n.Onboarding.privacyBody
                ) {
                    OnboardingPrivacyArt(isCurrent: page == 2)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 14) {
                OnboardingDots(count: lastPage + 1, current: page)

                // 固定占两行高度：翻到最后一页时出现，版面不跳。
                Text(L10n.Onboarding.cameraNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .opacity(page == lastPage ? 1 : 0)
                    .accessibilityHidden(page != lastPage)

                Button(action: advance) {
                    Text(page < lastPage ? L10n.Onboarding.next : L10n.Onboarding.start)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 30)
                        .contentTransition(.opacity)
                }
                .modifier(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.m)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: page)
        .animation(Theme.Motion.smooth, value: page)
    }

    private func advance() {
        guard page < lastPage else {
            onFinish()
            return
        }
        withAnimation(Theme.Motion.smooth) { page += 1 }
    }
}

/// 一页：上面插画（按可用高度等比缩放，永远完整显示），下面标题 + 说明。
private struct OnboardingPage<Art: View>: View {
    let isCurrent: Bool
    let title: String
    let message: String
    @ViewBuilder var art: () -> Art

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { proxy in
                let scale = min(1, proxy.size.width / 300, proxy.size.height / 320)
                art()
                    .frame(width: 300, height: 320)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxHeight: 340)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(message)
                    .font(.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .layoutPriority(1)
        }
        .padding(.vertical, 8)
        .onAppear(perform: reveal)
        .onChange(of: isCurrent) { _, current in
            if current { reveal() }
        }
    }

    private func reveal() {
        guard isCurrent, !shown else { return }
        withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion).delay(0.1)) {
            shown = true
        }
    }
}

// MARK: 第 1 页插画：取景框锁定

/// 深色「取景器」面板里一张码：取景框从大到小收拢、贴合到码上并变成薄荷绿，
/// 随后底部出现「链接安全」——和扫码页命中时的反馈一样。
private struct OnboardingScanArt: View {
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var code: UIImage?
    @State private var locked = false
    @State private var verdict = false
    @State private var played = false

    private static let panel = Color(hex: 0x0B0E14)
    private static let mint = Color(hex: 0x34D399)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Self.panel)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack {
                    if let code {
                        Image(uiImage: code)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    OnboardingFinderCorners()
                        .stroke(
                            locked ? Self.mint : Color.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: locked ? 168 : 216, height: locked ? 168 : 216)
                }
                .frame(width: 230, height: 230)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Self.mint)
                    Text(L10n.Onboarding.scanBadge)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.system(size: 15, weight: .semibold))
                .opacity(verdict ? 1 : 0)
                .offset(y: verdict || reduceMotion ? 0 : 10)
                .padding(.bottom, 26)
            }
        }
        .frame(width: 270, height: 320)
        .task {
            if code == nil { code = Self.makeCode() }
        }
        .onAppear(perform: play)
        .onChange(of: isCurrent) { _, current in
            if current { play() }
        }
        .sensoryFeedback(.success, trigger: locked) { _, new in new }
    }

    private func play() {
        guard isCurrent, !played else { return }
        played = true
        guard !reduceMotion else {
            locked = true
            verdict = true
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.45)) { locked = true }
        withAnimation(Theme.Motion.smooth.delay(0.95)) { verdict = true }
    }

    private static func makeCode() -> UIImage? {
        guard let preset = QRStylePreset.all.first(where: { $0.id == "ink" }) else { return nil }
        return try? BarcodeImageGenerator.render(
            value: "Leitor QR",
            kind: .qr,
            style: preset.applying(to: QRCodeStyle())
        )
    }
}

/// 四个圆角框角（和扫码页取景框同一种语言）。
private struct OnboardingFinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.22
        let radius: CGFloat = 16
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

// MARK: 第 2 页插画：换样式

/// 一张带 Wi-Fi 品牌图标的码，依次换成「墨韵 → 珊瑚 → 宝石蓝」三种精选样式（每次从中心圆形揭开），
/// 下面三个色点的选中环跟着滑过去。只播一遍，停在宝石蓝。
private struct OnboardingCreateArt: View {
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ringNamespace
    @State private var images: [String: UIImage] = [:]
    @State private var step = 0
    @State private var played = false

    private static let sequence = ["ink", "coral", "sapphire"]

    private var presets: [QRStylePreset] {
        Self.sequence.compactMap { id in QRStylePreset.all.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(Theme.Palette.border, lineWidth: 1)
                    )

                if presets.indices.contains(step), let image = images[presets[step].id] {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 176, height: 176)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .id(presets[step].id)
                        .transition(reduceMotion ? .opacity : .onboardingReveal)
                }
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 14) {
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    Circle()
                        .fill(Color(hex: preset.eyeHex ?? preset.foregroundHex))
                        .frame(width: 24, height: 24)
                        .padding(5)
                        .overlay {
                            if index == step {
                                Circle()
                                    .strokeBorder(Theme.Palette.primary, lineWidth: 2.5)
                                    .matchedGeometryEffect(id: "onboarding.ring", in: ringNamespace)
                            }
                        }
                }
            }

            Text(presets.indices.contains(step) ? presets[step].name : "")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.opacity)
        }
        .frame(width: 280, height: 320)
        .task { renderIfNeeded() }
        .onAppear(perform: play)
        .onChange(of: isCurrent) { _, current in
            if current { play() }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    private func play() {
        guard isCurrent, !played else { return }
        played = true
        guard !reduceMotion else {
            step = Self.sequence.count - 1
            return
        }
        // 每一步是单独的状态变化，所以用 sleep 排队；withAnimation 的 delay 只推迟动画、不推迟赋值。
        Task { @MainActor in
            for index in 1..<Self.sequence.count {
                try? await Task.sleep(nanoseconds: index == 1 ? 650_000_000 : 950_000_000)
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)) { step = index }
            }
        }
    }

    private func renderIfNeeded() {
        guard images.isEmpty else { return }
        var base = QRCodeStyle()
        base.logoSource = .brand
        base.logoTileHex = CreateType.wifi.brandHex
        let logo = BrandMarkRenderer.logo(for: .wifi, side: 84, color: .black)
        var result: [String: UIImage] = [:]
        for preset in presets {
            if let image = try? BarcodeImageGenerator.render(
                value: "WIFI:T:WPA;S:Leitor QR;P:leitorqr-2026;;",
                kind: .qr,
                style: preset.applying(to: base),
                logo: logo
            ) {
                result[preset.id] = image
            }
        }
        images = result
    }
}

private struct OnboardingRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask {
            GeometryReader { proxy in
                let diameter = hypot(proxy.size.width, proxy.size.height) * progress
                Circle()
                    .frame(width: diameter, height: diameter)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }
}

private extension AnyTransition {
    /// 新码从中心圆形揭开；旧码稍晚淡出，衔接不断。
    static var onboardingReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: OnboardingRevealModifier(progress: 0.001),
                identity: OnboardingRevealModifier(progress: 1)
            ),
            removal: .opacity.animation(.easeOut(duration: 0.3).delay(0.3))
        )
    }
}

// MARK: 第 3 页插画：隐私

/// 品牌蓝方块 + 白色盾牌，下面一张卡片三行承诺依次滑入。
private struct OnboardingPrivacyArt: View {
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var rows: [(symbol: String, title: String)] {
        [
            ("person.crop.circle.badge.xmark", L10n.Onboarding.privacyNoAccount),
            ("eye.slash.fill", L10n.Onboarding.privacyNoTracking),
            ("iphone", L10n.Onboarding.privacyLocal)
        ]
    }

    var body: some View {
        VStack(spacing: 26) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.Palette.primaryFill)
                .frame(width: 112, height: 112)
                .overlay {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(shown || reduceMotion ? 1 : 0.8)
                .opacity(shown ? 1 : 0)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Palette.primary)
                            .frame(width: 24)
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Palette.successText)
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(x: shown || reduceMotion ? 0 : 16)
                    .animation(
                        Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)
                            .delay(0.25 + Double(index) * 0.12),
                        value: shown
                    )
                }
            }
            .padding(18)
            .frame(width: 280)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
        .frame(width: 300, height: 320)
        .onAppear(perform: play)
        .onChange(of: isCurrent) { _, current in
            if current { play() }
        }
    }

    private func play() {
        guard isCurrent, !shown else { return }
        withAnimation(reduceMotion ? Theme.Motion.fade : .spring(response: 0.5, dampingFraction: 0.75)) {
            shown = true
        }
    }
}

// MARK: 页码 / 按钮

/// 当前页是一段拉长的品牌蓝胶囊，其余是小圆点。
private struct OnboardingDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == current ? Theme.Palette.primary : Theme.Palette.border)
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
        .animation(Theme.Motion.snappy, value: current)
        .accessibilityHidden(true)
    }
}

private struct OnboardingPrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Theme.Palette.primaryFill)
                .foregroundStyle(.white)
        } else {
            content.buttonStyle(PrimaryButtonStyle())
        }
    }
}
