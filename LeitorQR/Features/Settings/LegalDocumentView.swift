import SwiftUI

/// 法律条款与隐私政策的文案类型
enum LegalDocumentType: String, Identifiable, Hashable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return L10n.Legal.termsTitle
        case .privacy: return L10n.Legal.privacyTitle
        }
    }

    var iconName: String {
        switch self {
        case .terms: return "doc.text.fill"
        case .privacy: return "hand.raised.fill"
        }
    }

    var summaryText: String {
        switch self {
        case .terms: return L10n.Legal.termsSummary
        case .privacy: return L10n.Legal.privacySummary
        }
    }

    var sections: [LegalSectionItem] {
        switch self {
        case .privacy:
            return [
                LegalSectionItem(title: L10n.Legal.privacySec1Title, body: L10n.Legal.privacySec1Body),
                LegalSectionItem(title: L10n.Legal.privacySec2Title, body: L10n.Legal.privacySec2Body),
                LegalSectionItem(title: L10n.Legal.privacySec3Title, body: L10n.Legal.privacySec3Body),
                LegalSectionItem(title: L10n.Legal.privacySec4Title, body: L10n.Legal.privacySec4Body),
                LegalSectionItem(title: L10n.Legal.privacySec5Title, body: L10n.Legal.privacySec5Body)
            ]
        case .terms:
            return [
                LegalSectionItem(title: L10n.Legal.termsSec1Title, body: L10n.Legal.termsSec1Body),
                LegalSectionItem(title: L10n.Legal.termsSec2Title, body: L10n.Legal.termsSec2Body),
                LegalSectionItem(title: L10n.Legal.termsSec3Title, body: L10n.Legal.termsSec3Body),
                LegalSectionItem(title: L10n.Legal.termsSec4Title, body: L10n.Legal.termsSec4Body),
                LegalSectionItem(title: L10n.Legal.termsSec5Title, body: L10n.Legal.termsSec5Body)
            ]
        }
    }
}

struct LegalSectionItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

/// App 内部原生实现的法律文档阅读器（使用条款与隐私政策），告别外部网页依赖。
struct LegalDocumentView: View {

    let type: LegalDocumentType
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasCopiedEmail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                headerBanner

                summaryCard

                ForEach(type.sections) { section in
                    sectionCard(section)
                }

                contactCard
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.l)
        }
        .screenBackground()
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 顶栏标识

    private var headerBanner: some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.primary.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: type.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(type.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text(L10n.Legal.lastUpdated)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - 摘要导读卡片

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Palette.primary)
                .padding(.top, 2)

            Text(type.summaryText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineSpacing(3)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Palette.primary.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Palette.primary.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 正文章节卡片

    private func sectionCard(_ section: LegalSectionItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(section.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(section.body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(4)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 1)
        )
    }

    // MARK: - 底部官方联系卡

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.Palette.primary)
                Text(L10n.Legal.contactTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
            }

            Text(L10n.Legal.contactDesc)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack {
                Text(SubscriptionManager.supportEmail)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.Palette.primary)

                Spacer()

                Button {
                    UIPasteboard.general.string = SubscriptionManager.supportEmail
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    hasCopiedEmail = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        hasCopiedEmail = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasCopiedEmail ? "checkmark" : "doc.on.doc")
                        Text(hasCopiedEmail ? L10n.Legal.emailCopied : L10n.Legal.copyEmail)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
            .padding(Theme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            Link(destination: SubscriptionManager.supportURL) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text(L10n.Legal.sendEmail)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Theme.Palette.primaryFill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 1)
        )
        .padding(.top, Theme.Spacing.xs)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color.white
    }
}

#Preview {
    NavigationStack {
        LegalDocumentView(type: .privacy, isModal: true)
    }
}
