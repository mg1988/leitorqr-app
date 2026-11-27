import Foundation
import SwiftUI

/// 付费墙智能触发与频控管理器。
///
/// 核心准则（PRD / HIG 订阅规范）：
/// 1. **价值优先（Value Before Ask）**：冷启动付费墙只在本进程完成首次完整扫码/制码之后出现；
///    postAha（成就时刻）仍是 3 次完整扫码或 2 次制码。装完即弹是 Guideline 4.5 的高危模式。
/// 2. **频控保护（Cool-down Protection）**：系统主动触发的付费墙，用户关闭后至少保留 24 小时冷却期，决不连续骚扰。
/// 3. **意图豁免**：用户主动点击 PRO 模板、上传 Logo 或在设置页点击时，不受冷却期限制，立刻响应用户真实意图。
///
/// 呈现层唯一入口是 `RootTabView` 的 fullScreenCover：任何页面都不要再挂
/// 一个 `sheet(isPresented:)`，同一视图树里的两个 presentation 会互相吞掉。
final class PaywallTriggerManager: ObservableObject {

    static let shared = PaywallTriggerManager()

    enum TriggerReason: Equatable {
        case direct              // 用户在设置/历史等主动点击
        case coldLaunch          // 未订阅冷启动弹出
        case featureGate(String) // 触发了高级模版或自定义 Logo 功能锁
        case usageLimit          // 达到历史记录 10 条上限
        case postAha             // 达成体验高光时刻（多次成功扫码）
    }

    @Published var isPaywallPresented: Bool = false
    @Published var triggerReason: TriggerReason = .direct

    private let defaults = UserDefaults.standard

    private let scanCountKey = "paywall_scan_success_count"
    private let generateCountKey = "paywall_generate_success_count"
    private let lastDismissKey = "paywall_last_dismissed_at"
    private let ahaShownKey = "paywall_aha_shown_once"

    /// 自动弹出的冷却时间：24 小时
    private let coolDownInterval: TimeInterval = 24 * 3600
    /// 冷启动在本次进程里只判断一次，避免订阅状态多次刷新时反复弹。
    private var didAttemptColdLaunch = false
    /// 订阅首次刷新是否已完成（防止把还没确定的 .unknown 当成「未订阅」）。
    private var isSubscriptionRefreshCompleted = false
    /// 刷新完成时的订阅状态。
    private var lastKnownPremium = false
    /// 本次进程是否已发生「价值时刻」（完整扫码/成功制码各一次）。
    /// 冷启动付费墙绝不在这之前出现——装完即弹是 Guideline 4.5 的高危拒审模式。
    private var hasValueMomentThisSession = false

    private init() {}

    // MARK: - 状态读取

    var scanSuccessCount: Int {
        defaults.integer(forKey: scanCountKey)
    }

    var generateSuccessCount: Int {
        defaults.integer(forKey: generateCountKey)
    }

    var lastDismissedDate: Date? {
        let timestamp = defaults.double(forKey: lastDismissKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// 当前是否处于 24 小时防骚扰冷却期中
    var isCoolDownActive: Bool {
        guard let last = lastDismissedDate else { return false }
        return Date().timeIntervalSince(last) < coolDownInterval
    }

    // MARK: - 呈现与关闭

    /// 用户关闭付费墙时调用。只有**系统主动**触发的才写入冷却期；
    /// 用户自己点开的 PRO 入口关掉后不该把 postAha 触发屏蔽 24 小时。
    func recordDismiss() {
        switch triggerReason {
        case .coldLaunch, .postAha, .usageLimit:
            defaults.set(Date().timeIntervalSince1970, forKey: lastDismissKey)
        case .direct, .featureGate:
            break
        }
        isPaywallPresented = false
    }

    /// 购买成功：只收起页面，不写「用户关闭」的冷却期。
    func dismissWithoutCooldown() {
        isPaywallPresented = false
    }

    /// 订阅首次刷新完成时调用（RootTabView）。
    /// 只登记状态，不直接弹付费墙——还要等本次进程的首次价值时刻。
    func markSubscriptionRefreshCompleted(isPremium: Bool) {
        isSubscriptionRefreshCompleted = true
        lastKnownPremium = isPremium
        attemptColdLaunchIfNeeded()
    }

    /// 冷启动付费墙统一入口：两个前置条件（订阅刷新完成 + 首次价值时刻）都满足时才弹。
    /// 哪个条件后到就在哪个时机弹；本次进程最多弹一次。
    private func attemptColdLaunchIfNeeded() {
        guard !didAttemptColdLaunch else { return }
        guard isSubscriptionRefreshCompleted, hasValueMomentThisSession else { return }
        guard !lastKnownPremium, !isCoolDownActive, !isPaywallPresented else { return }
        didAttemptColdLaunch = true
        triggerReason = .coldLaunch
        isPaywallPresented = true
    }

    // MARK: - 事件记录

    /// 成功扫码一次（结果页关闭后调用）
    @discardableResult
    func recordScanSuccess(isPremium: Bool) -> Bool {
        let current = scanSuccessCount + 1
        defaults.set(current, forKey: scanCountKey)

        // 首次完整扫码 = 价值时刻。冷启动付费墙改在这里出现，
        // 而不是 App 一打开就拦脸。若这次弹的是冷启动墙，直接结束（别再叠加 postAha）。
        hasValueMomentThisSession = true
        if !isPremium, !didAttemptColdLaunch, !isCoolDownActive, !isPaywallPresented {
            attemptColdLaunchIfNeeded()
            if isPaywallPresented { return true }
        }

        guard !isPremium else { return false }
        guard !isCoolDownActive else { return false }

        // 仅在第 3 次成功扫码且此前从未弹出过 Aha 付费墙时尝试触发
        let alreadyShown = defaults.bool(forKey: ahaShownKey)
        if current >= 3 && !alreadyShown {
            defaults.set(true, forKey: ahaShownKey)
            triggerReason = .postAha
            isPaywallPresented = true
            return true
        }
        return false
    }

    /// 成功生成并保存一次二维码
    @discardableResult
    func recordGenerateSuccess(isPremium: Bool) -> Bool {
        let current = generateSuccessCount + 1
        defaults.set(current, forKey: generateCountKey)

        // 制码同样算价值时刻（冷启动墙的另一个前置条件）。
        hasValueMomentThisSession = true
        if !isPremium, !didAttemptColdLaunch, !isCoolDownActive, !isPaywallPresented {
            attemptColdLaunchIfNeeded()
            if isPaywallPresented { return true }
        }

        guard !isPremium else { return false }
        guard !isCoolDownActive else { return false }

        let alreadyShown = defaults.bool(forKey: ahaShownKey)
        if current >= 2 && !alreadyShown {
            defaults.set(true, forKey: ahaShownKey)
            triggerReason = .postAha
            isPaywallPresented = true
            return true
        }
        return false
    }

    /// 设置页会员卡片：用户主动打开，用默认标题「解锁 Leitor QR Premium」，不受冷却期限制。
    func openFromSettings() {
        triggerReason = .direct
        isPaywallPresented = true
    }

    /// 用户主动点了历史页的配额条：情境是「历史已满 / 快满」，标题用 usageLimit 那一套。
    /// 和 featureGate 一样是用户主动发起，不受冷却期限制。
    func triggerUsageLimit() {
        triggerReason = .usageLimit
        isPaywallPresented = true
    }

    /// 触发功能锁（不受冷却期限制，因为是用户主动行为）
    func triggerFeatureGate(_ featureName: String) {
        triggerReason = .featureGate(featureName)
        isPaywallPresented = true
    }
}
