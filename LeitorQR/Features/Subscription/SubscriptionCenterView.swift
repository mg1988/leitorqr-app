import SwiftUI

/// 订阅透明中心（正式功能，不是普通设置链接）。
/// 所有状态都来自 StoreKit 的真实交易与订阅状态，不使用固定文案或虚构日期。
struct SubscriptionCenterView: View {

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var showManageFallback = false
    @State private var isManaging = false

    private var snapshot: SubscriptionSnapshot { subscriptions.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                statusCard

                if snapshot.state != .none && snapshot.state != .unknown {
                    detailsCard
                }

                manageBlock
                infoBlock

                if !subscriptions.isPremium {
                    upgradeLink
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.m)
        }
        .screenBackground()
        .navigationTitle(L10n.Subscription.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await subscriptions.refresh() }
        .task { await subscriptions.refresh() }
        .alert(L10n.Subscription.manage, isPresented: $showManageFallback) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Subscription.manageFallback) {
                openURL(SubscriptionManager.appleSubscriptionsURL)
            }
        } message: {
            Text(L10n.Subscription.unavailable)
        }
    }

    // MARK: - 状态

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                StatusBadge(
                    text: snapshot.statusText,
                    tint: statusTint,
                    icon: statusIcon
                )
                Spacer(minLength: 0)
                if subscriptions.isLoading {
                    ProgressView()
                }
            }

            Text(snapshot.displayName ?? L10n.Subscription.planFree)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            // 买断没有订阅周期（periodText 为 nil），只能显示价格本身。
            // 旧写法在 periodText 缺失时会掉进 `displayName != nil` 分支，
            // 给已付费用户显示「免费版」。
            if let price = snapshot.displayPrice {
                Group {
                    if let period = snapshot.periodText {
                        Text("\(price) / \(period)")
                    } else {
                        Text(price)
                    }
                }
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .card()
    }

    // MARK: - 明细

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.Subscription.planTitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.bottom, Theme.Spacing.xxs)

            if let price = snapshot.displayPrice {
                detailRow(L10n.Subscription.price, price)
            }
            if let period = snapshot.periodText {
                detailRow(L10n.Subscription.period, period)
            }

            switch snapshot.state {
            case .trial:
                if let date = snapshot.trialEndDate {
                    detailRow(L10n.Subscription.trialEnd, dateText(date))
                }
            case .active, .billingIssue:
                if let date = snapshot.renewalDate ?? snapshot.expirationDate {
                    detailRow(L10n.Subscription.renewalDate, dateText(date))
                }
            case .cancelled, .expired:
                if let date = snapshot.expirationDate {
                    detailRow(L10n.Subscription.expiryDate, dateText(date))
                }
            case .weeklyPass:
                if let date = snapshot.expirationDate {
                    detailRow(L10n.Subscription.expiryDate, dateText(date))
                }
            default:
                EmptyView()
            }

            // 买断没有续订概念，不能显示「自动续订：关闭」。
            if let willRenew = snapshot.willAutoRenew, !snapshot.isLifetime {
                detailRow(
                    L10n.Subscription.autoRenew,
                    willRenew ? L10n.Subscription.autoRenewOn : L10n.Subscription.autoRenewOff
                )
            }
        }
        .card()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: Theme.Spacing.xs)
            Text(value)
                .font(Theme.Typography.bodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - 管理

    @ViewBuilder
    private var manageBlock: some View {
        if snapshot.isLifetime || snapshot.state == .weeklyPass {
            // 买断与体验卡都是一次性商品，没有订阅可取消。
            let note = snapshot.isLifetime
                ? L10n.Paywall.planLifetimeNote
                : L10n.Paywall.planWeeklyNote
            Text(note)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .card()
        } else {
        VStack(spacing: Theme.Spacing.xs) {
            Button {
                manageSubscription()
            } label: {
                if isManaging {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(L10n.Subscription.manage, systemImage: "arrow.up.forward.app")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isManaging)

            Button(L10n.Subscription.manageFallback) {
                openURL(SubscriptionManager.appleSubscriptionsURL)
            }
            .buttonStyle(TextButtonStyle())
        }
        }
    }

    // MARK: - 说明

    @ViewBuilder
    private var infoBlock: some View {
        if snapshot.isLifetime || snapshot.state == .weeklyPass {
            EmptyView()
        } else {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(L10n.Subscription.infoTitle)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(L10n.Subscription.cancelInfo)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.Subscription.refundInfo)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        }
    }

    private var upgradeLink: some View {
        NavigationLink {
            PaywallView(showsCloseButton: false, triggerReason: .direct)
        } label: {
            HStack {
                SparklesMark(size: 16)
                Text(L10n.Subscription.upgrade)
                Spacer()
                ChevronRightMark(size: 12)
            }
            .font(Theme.Typography.bodyEmphasis)
            .foregroundStyle(Theme.Palette.primary)
            .padding(Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 行为

    private func manageSubscription() {
        isManaging = true
        Task { @MainActor in
            let opened = await subscriptions.showManageSubscriptions()
            isManaging = false
            if !opened {
                showManageFallback = true
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    private var statusTint: Color {
        switch snapshot.state {
        case .trial, .active: return Theme.Palette.success
        case .cancelled: return Theme.Palette.warning
        case .billingIssue, .expired: return Theme.Palette.error
        case .lifetime: return Theme.Palette.primary
        case .weeklyPass: return Theme.Palette.primary
        case .none, .unknown: return Theme.Palette.textSecondary
        }
    }

    private var statusIcon: String {
        switch snapshot.state {
        case .trial: return "clock"
        case .active: return "checkmark.circle"
        case .cancelled: return "exclamationmark.circle"
        case .billingIssue: return "creditcard.trianglebadge.exclamationmark"
        case .expired: return "xmark.circle"
        case .lifetime: return "infinity"
        case .weeklyPass: return "hourglass"
        case .none, .unknown: return "info.circle"
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionCenterView()
            .environmentObject(SubscriptionManager())
    }
}
