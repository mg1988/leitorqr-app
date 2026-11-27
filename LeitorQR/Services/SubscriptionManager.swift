import Combine
import Foundation
import StoreKit
import UIKit

/// 权益状态。`billingIssue`（宽限期/账单重试）期间仍保留 Premium——不能因为一次账单问题立刻锁死用户。
enum EntitlementState: Equatable {
    case unknown
    case none
    case trial
    case active
    case cancelled
    case expired
    case billingIssue
    /// 一次性买断：没有到期日、没有续订，永远有效。
    case lifetime
    /// 7 天体验卡：一次性购买，按交易 purchaseDate 算 7 天，到期自动回落免费版。
    case weeklyPass
}

struct SubscriptionSnapshot: Equatable {
    var state: EntitlementState = .unknown
    var displayName: String?
    var displayPrice: String?
    var periodText: String?
    var trialEndDate: Date?
    var renewalDate: Date?
    var expirationDate: Date?
    var willAutoRenew: Bool?

    var hasPremium: Bool {
        switch state {
        case .trial, .active, .cancelled, .billingIssue, .lifetime, .weeklyPass: return true
        case .unknown, .none, .expired: return false
        }
    }

    /// 买断用户没有续订可管，订阅中心要据此隐藏「管理订阅 / 下次续订」。
    var isLifetime: Bool { state == .lifetime }

    var statusText: String {
        switch state {
        case .unknown: return L10n.Subscription.statusUnknown
        case .none: return L10n.Subscription.statusNone
        case .trial: return L10n.Subscription.statusTrial
        case .active: return L10n.Subscription.statusActive
        case .cancelled: return L10n.Subscription.statusCancelled
        case .expired: return L10n.Subscription.statusExpired
        case .billingIssue: return L10n.Subscription.statusBilling
        case .lifetime: return L10n.Subscription.statusLifetime
        case .weeklyPass: return L10n.Subscription.statusWeeklyPass
        }
    }
}

/// StoreKit 2 订阅管理：商品加载、购买、恢复、交易监听、权益判断。
///
/// 规则（PRD 6.8）：
/// - 权益只以已验证的交易/订阅状态为准，不用 UserDefaults 布尔值。
/// - 网络失败时不清除已验证权益；离线也能读到本地交易记录。
final class SubscriptionManager: ObservableObject {

    // 三档：年订阅（带试用，主力）、月订阅（低门槛）、一次性买断（无续订）。
    // 订阅和买断是两种完全不同的商品，权益判断必须分开走。
    static let yearlyProductID = "com.leitorqr.premium.yearly"
    static let monthlyProductID = "com.leitorqr.premium.monthly"
    /// 终身买断（ASC 里建「非消耗型项目」，App 的 Bundle ID 是 com.mg.localicard）。
    static let lifetimeProductID = "com.mg.localicard.premium.lifetime"
    /// 改 ID 之前用过的买断 ID：如果 ASC 里曾经建过并有人买过，照样认作终身权益。
    static let legacyLifetimeProductIDs = ["com.leitorqr.premium.lifetime"]
    /// 7 天体验卡：一次性低价商品，有效期从交易的 purchaseDate 算 7 天。
    static let weeklyPassProductID = "com.leitorqr.premium.weeklypass"
    static let weeklyPassDuration: TimeInterval = 7 * 24 * 3600
    /// 同一订阅组内的产品：共用试用资格，用户在组内只能享受一次 introductory offer。
    static let subscriptionProductIDs = [yearlyProductID, monthlyProductID]
    /// 在售商品：**只有买断**（2026-11-27 体验卡下架）。
    /// 体验卡与老订阅的 ID 保留在 `legacyProductIDs` 里，只用于识别已购用户的既有权益，
    /// 不进入 `Product.products(for:)` 请求，也不出现在付费墙和设置页。
    static let allProductIDs = [lifetimeProductID]
    /// 已下架但仍需识别权益的商品：7 天体验卡 + 老订阅。交易监听要放行它们（退款要能及时生效）。
    static let legacyProductIDs = [weeklyPassProductID] + subscriptionProductIDs + legacyLifetimeProductIDs

    /// 兼容旧引用点（付费墙、交易监听）。默认指年订阅。
    static let productID = yearlyProductID
    static let supportEmail = "genweimi@gmail.com"
    static let supportURL = URL(string: "mailto:genweimi@gmail.com")!

    // MARK: 官网
    //
    // docs/ 下是官网静态页（首页 / 支持 / 隐私与条款，由 scripts/gen_site.py 生成）。
    // 托管好之后（例如 GitHub Pages）把根地址填到 websiteURL，末尾不要斜杠，例如：
    //   URL(string: "https://你的用户名.github.io/leitorqr")
    // App Store Connect 里的「技术支持网址」填 …/support.html，「隐私政策网址」填 …/privacy-policy.html。
    /// nil = 还没托管。
    static let websiteURL: URL? = nil
    static var supportPageURL: URL? { websiteURL?.appendingPathComponent("support.html") }
    static var privacyPageURL: URL? { websiteURL?.appendingPathComponent("privacy-policy.html") }

    /// 设置页会员卡、付费墙模板扇面里那些装饰二维码的内容。
    /// 官网没托管时只放 App 名（纯文本）：扫出来不会打开一个不属于我们的网站。
    static var showcaseCodeValue: String {
        websiteURL?.absoluteString ?? "Leitor QR"
    }
    static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case pending
        case success
        case cancelled
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var snapshot = SubscriptionSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    /// 账号在订阅组内是否还有 introductory offer 资格。
    /// **默认 false**：没拿到商品、没查到订阅组时一律视为「没有资格」——
    /// 宁可少显示一次试用，也不能凭空承诺一个后台没配、或用户已经用过的试用。
    @Published private(set) var isEligibleForIntroOffer = false
    /// 首次 start() 完成（含商品与权益刷新）后置 true，冷启动付费墙据此判断。
    @Published private(set) var hasCompletedInitialRefresh = false
    @Published var purchaseState: PurchaseState = .idle

    private var updatesTask: Task<Void, Never>?
    private var didStart = false

    var isPremium: Bool {
        #if DEBUG
        // 截图/验收用：simctl 不加载 StoreKit 配置，无法拿到真实订阅态。
        if DebugLaunchOptions.forcePremium { return true }
        #endif
        // 体验卡到期不依赖 App 重启：snapshot 里的到期日已过就立刻失去权益。
        if snapshot.state == .weeklyPass,
           let expiry = snapshot.expirationDate,
           expiry <= Date() { return false }
        return snapshot.hasPremium
    }
    /// 默认商品 = 买断。付费墙、试用资格判断都走它。
    var product: Product? {
        product(id: Self.lifetimeProductID) ?? products.first
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    var hasLoadedProduct: Bool { !products.isEmpty }

    /// 某档商品真实的免费试用周期。**只有三个条件同时成立才有值**：
    /// 1. 商品已经从 StoreKit 拿到（后台配了这档、网络正常）；
    /// 2. 该商品带 introductory offer，且优惠模式是 `.freeTrial`（降价促销不算试用）；
    /// 3. 当前账号在订阅组内还没用过试用资格。
    /// 任一不满足返回 nil，UI 就不显示任何试用文案——试用是后台数据，不是本地默认值。
    func freeTrialPeriod(for productID: String) -> Product.SubscriptionPeriod? {
        guard isEligibleForIntroOffer,
              let offer = product(id: productID)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return offer.period
    }

    // MARK: - 启动

    @MainActor
    func start() async {
        guard !didStart else { return }
        didStart = true
        listenForTransactionUpdates()
        await refresh()
        hasCompletedInitialRefresh = true
    }

    /// 拉取商品 + 重新计算权益。可被设置页、订阅中心手动触发。
    @MainActor
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            if !loaded.isEmpty {
                // 按固定顺序排，避免 StoreKit 返回顺序影响付费墙的档位排列。
                products = Self.allProductIDs.compactMap { id in
                    loaded.first { $0.id == id }
                }
            }
        } catch {
            // 网络失败不清除已有商品与权益，仅记录错误。
            lastError = error.localizedDescription
        }

        // 传空 groupID 会让 StoreKit 返回不确定的资格；只有真拿到订阅组才查询。
        if let groupID = product?.subscription?.subscriptionGroupID {
            isEligibleForIntroOffer = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
        }

        await refreshEntitlement()
    }

    // MARK: - 权益判断

    @MainActor
    private func refreshEntitlement() async {
        // 买断优先：它没有到期日，也不参与订阅组的任何状态流转。
        if let lifetime = await lifetimeEntitlement() {
            var next = SubscriptionSnapshot(state: .lifetime)
            next.displayName = product(id: Self.lifetimeProductID)?.displayName
            next.displayPrice = product(id: Self.lifetimeProductID)?.displayPrice
            next.expirationDate = nil
            next.renewalDate = nil
            next.willAutoRenew = false
            _ = lifetime
            snapshot = next
            lastError = nil
            return
        }

        // 有效订阅（老用户）：仍按订阅组状态判断，权益保留到到期。
        if let subscription = subscriptionForStatus()?.subscription {
            await refreshSubscriptionEntitlement(subscription)
            return
        }

        // 本地交易兜底：先看老订阅是否仍在有效期。
        if await hasActiveLegacySubscription() {
            await entitlementFromLocalTransactions()
            return
        }

        // 体验卡：一次性商品的有效期按 StoreKit 交易时间算，不存本地，
        // 换设备 / 重装后 currentEntitlements 仍能恢复，到期自动失效。
        if let pass = await weeklyPassEntitlement() {
            var next = SubscriptionSnapshot(state: .weeklyPass)
            // 体验卡已下架、不再请求商品信息，名称用本地文案；价格不显示。
            next.displayName = L10n.Paywall.planWeekly
            next.displayPrice = nil
            next.trialEndDate = pass.purchaseDate.addingTimeInterval(Self.weeklyPassDuration)
            next.expirationDate = next.trialEndDate
            next.willAutoRenew = false
            snapshot = next
            lastError = nil
            return
        }

    }

    /// 老订阅用户的权益解析：沿用 StoreKit 订阅组状态。
    @MainActor
    private func refreshSubscriptionEntitlement(_ subscription: Product.SubscriptionInfo) async {
        do {
            let statuses = try await subscription.status
            // 同一订阅组会返回多条状态（换套餐、旧订阅残留、家庭共享）。
            // 优先取真正生效的那条（`subscribed`），不能盲取 `.first`。
            let usable = statuses.filter { item in
                if case .verified = item.transaction { return true }
                return false
            }
            let status = usable.first { $0.state == .subscribed } ?? usable.first
            guard let status else {
                snapshot = SubscriptionSnapshot(state: .none)
                return
            }

            var next = SubscriptionSnapshot()
            var subscribedID: String?
            var isFreeTrial = false
            if case .verified(let transaction) = status.transaction {
                subscribedID = transaction.productID
                next.expirationDate = transaction.expirationDate
                if #available(iOS 17.2, *) {
                    if let offer = transaction.offer, offer.paymentMode == .freeTrial {
                        isFreeTrial = true
                    }
                } else if transaction.offerType == .introductory {
                    isFreeTrial = true
                }
            }

            // 展示用户实际订的那一档（可能是月订阅），不是固定的年订阅。
            let active = subscribedID.flatMap { product(id: $0) }
                ?? Self.subscriptionProductIDs.compactMap({ product(id: $0) }).first
            next.displayName = active?.displayName
            next.displayPrice = active?.displayPrice
            next.periodText = Self.periodText(active?.subscription?.subscriptionPeriod)

            if case .verified(let renewal) = status.renewalInfo {
                next.willAutoRenew = renewal.willAutoRenew
            }

            // RenewalState 是 RawRepresentable 结构体，用等值比较而非 switch。
            let renewalState = status.state
            if renewalState == .subscribed {
                if isFreeTrial {
                    next.state = .trial
                    next.trialEndDate = next.expirationDate
                } else if next.willAutoRenew == false {
                    // 用户已关闭自动续订：当前周期内权益必须保留。
                    next.state = .cancelled
                } else {
                    next.state = .active
                    next.renewalDate = next.expirationDate
                }
            } else if renewalState == .inGracePeriod || renewalState == .inBillingRetryPeriod {
                next.state = .billingIssue
            } else if renewalState == .expired || renewalState == .revoked {
                next.state = .expired
            } else {
                next.state = .none
            }

            snapshot = next
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            await entitlementFromLocalTransactions()
        }
    }

    /// 未退款且仍在 7 天内的体验卡交易。有效期用交易的 purchaseDate，不依赖本地存档。
    private func weeklyPassEntitlement() async -> Transaction? {
        let now = Date()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.weeklyPassProductID,
                  transaction.revocationDate == nil else { continue }
            let expiry = transaction.purchaseDate.addingTimeInterval(Self.weeklyPassDuration)
            if expiry > now { return transaction }
        }
        return nil
    }

    /// 老订阅是否仍在有效期（本地交易兜底，覆盖网络失败的情况）。
    private func hasActiveLegacySubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.subscriptionProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  let expiry = transaction.expirationDate,
                  expiry > Date() else { continue }
            return true
        }
        return false
    }

    /// 已购买且未退款的一次性买断。买断交易永远留在 `currentEntitlements` 里。
    private func lifetimeEntitlement() async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.lifetimeProductID
                    || Self.legacyLifetimeProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            return transaction
        }
        return nil
    }

    /// 任一订阅产品即可查询订阅组状态（同组产品的 `status` 结果一致）。
    private func subscriptionForStatus() -> Product? {
        for id in Self.subscriptionProductIDs {
            if let product = product(id: id) { return product }
        }
        return nil
    }

    /// 没有商品信息或读取状态失败时的兜底：只看本地已验证交易。
    @MainActor
    private func entitlementFromLocalTransactions() async {
        var latest: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.subscriptionProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            // 多笔时取到期最晚的那笔，而不是序列末位。
            if let current = latest,
               let currentExpiry = current.expirationDate,
               let candidateExpiry = transaction.expirationDate,
               currentExpiry >= candidateExpiry { continue }
            latest = transaction
        }

        guard let transaction = latest,
              let expiration = transaction.expirationDate,
              expiration > Date() else {
            snapshot = SubscriptionSnapshot(state: .none)
            return
        }

        var next = SubscriptionSnapshot(state: .active)
        let active = product(id: transaction.productID)
        next.displayName = active?.displayName
        next.displayPrice = active?.displayPrice
        next.periodText = Self.periodText(active?.subscription?.subscriptionPeriod)
        next.expirationDate = expiration
        next.renewalDate = expiration
        snapshot = next
    }

    // MARK: - 购买 / 恢复

    /// 购买指定商品。现在只有买断一个可购商品。
    @MainActor
    func purchase(id: String = SubscriptionManager.lifetimeProductID) async {
        guard purchaseState != .purchasing else { return }
        guard let product = product(id: id) else {
            lastError = L10n.Subscription.unavailable
            return
        }
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .success
                    await refresh()
                case .unverified:
                    purchaseState = .failed(L10n.Paywall.purchaseFailed)
                }
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .cancelled
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            lastError = error.localizedDescription
            purchaseState = .failed(L10n.Paywall.purchaseFailed)
        }
    }

    /// 返回是否成功拿到有效权益。
    @discardableResult
    @MainActor
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refresh()
            return isPremium
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// 打开 Apple 系统订阅管理界面。失败时由调用方提供备用链接。
    @MainActor
    func showManageSubscriptions() async -> Bool {
        guard let scene = Self.activeWindowScene() else { return false }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - 交易监听

    @MainActor
    private func listenForTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, !Task.isCancelled else { break }
                // 放行老订阅的交易更新，否则老用户的续订/退款无法及时反映到权益。
                let known = Self.allProductIDs + Self.legacyProductIDs
                guard case .verified(let transaction) = result,
                      known.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self.refresh()
            }
        }
    }

    // MARK: - 工具

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    static func periodText(_ period: Product.SubscriptionPeriod?) -> String? {
        guard let period else { return nil }
        switch period.unit {
        case .day:
            return period.value == 1
                ? L10n.Period.daySingular
                : String(format: L10n.Period.dayPlural, period.value)
        case .week:
            return String(format: L10n.Period.dayPlural, period.value * 7)
        case .month:
            return period.value == 1
                ? L10n.Period.monthSingular
                : String(format: L10n.Period.monthPlural, period.value)
        case .year:
            return period.value == 1
                ? L10n.Period.yearSingular
                : String(format: L10n.Period.yearPlural, period.value)
        @unknown default:
            return nil
        }
    }
}
