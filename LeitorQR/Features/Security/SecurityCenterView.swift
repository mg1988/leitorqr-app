import SwiftUI

/// 安全中心的入口：基础三级提示免费，历史 / 白名单 / 批量检测为 PRO 权益。
struct SecurityCenterView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager

    private var isPremium: Bool { subscriptions.isPremium }

    var body: some View {
        List {
            Section {
                securityLink(
                    icon: "clock.arrow.circlepath",
                    tint: Theme.Palette.primaryFill,
                    title: L10n.Security.historyTitle,
                    subtitle: L10n.Security.historySubtitle,
                    gate: "security.history"
                ) { RiskHistoryView() }

                securityLink(
                    icon: "checkmark.shield.fill",
                    tint: Theme.Palette.successText,
                    title: L10n.Security.whitelistTitle,
                    subtitle: L10n.Security.whitelistSubtitle,
                    gate: "security.whitelist"
                ) { WhitelistView() }

                securityLink(
                    icon: "square.stack.3d.up.fill",
                    tint: ScanContentType.contact.tint,
                    title: L10n.Security.batchTitle,
                    subtitle: L10n.Security.batchSubtitle,
                    gate: "security.batch"
                ) { BatchRiskScanView() }
            } header: {
                Text(L10n.Security.sectionTools)
            } footer: {
                Text(isPremium ? L10n.Security.footerPaid : L10n.Security.footer)
            }

            Section {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Theme.Palette.successText)
                    Text(L10n.Security.privacyNote)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(L10n.Security.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 付费用户直接进功能页；未付费点整行就走同一个付费墙入口，
    /// 不用 `.disabled + onTapGesture`（disabled 会吞掉手势）。
    @ViewBuilder
    private func securityLink<Destination: View>(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        gate: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        let row = featureRow(icon: icon, tint: tint, title: title, subtitle: subtitle, locked: !isPremium)
        if isPremium {
            NavigationLink { destination() } label: { row }
        } else {
            Button {
                PaywallTriggerManager.shared.triggerFeatureGate(gate)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }

    /// 彩色图标块 + 标题 / 说明；未解锁时右侧是 PRO 胶囊（比一把锁更说得清「要什么才能用」）。
    private func featureRow(icon: String, tint: Color, title: String, subtitle: String, locked: Bool) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            SettingsIcon(systemImage: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if locked {
                Text(L10n.Paywall.proBadge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.Palette.primarySoft, in: Capsule())
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
