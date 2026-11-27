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
    #if DEBUG
    @State private var showLanguagePicker = false
    #endif

    private var currentColorScheme: ColorScheme? {
        AppAppearance(rawValue: appearanceRaw)?.colorScheme
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(isActive: selectedTab == .scan)
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
            if DebugLaunchOptions.isAutomation { return }
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
        // 语言切换后重建整棵视图树：L10n 是计算属性，重建时全部重新读取新 Bundle。
        .id(language.revision)
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
