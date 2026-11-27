import SwiftUI

// MARK: - 按钮样式

/// 主操作按钮：实心品牌色胶囊。按下轻微缩小，松手弹回。
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    /// 高风险场景下的「仍要打开」：改成危险色描边，不再用实心主色诱导点击。
    var isCaution: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(isCaution ? Theme.Palette.error : Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(isCaution ? Color.clear : Theme.Palette.primaryFill.opacity(isEnabled ? 1 : 0.35))
            )
            .overlay {
                if isCaution {
                    Capsule(style: .continuous).strokeBorder(Theme.Palette.error, lineWidth: 1.5)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

/// 次操作按钮：描边 + 卡片底色。
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(Theme.Palette.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

/// 纯文字按钮。
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyEmphasis)
            .foregroundStyle(Theme.Palette.primary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - 卡片

struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Spacing.m

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.m) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// 页面背景（含 Tab 之外的空白区域）。
    func screenBackground() -> some View {
        background(Theme.Palette.background.ignoresSafeArea())
    }
}

// MARK: - 徽标

struct StatusBadge: View {
    let text: String
    var tint: Color = Theme.Palette.primary
    var icon: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(Theme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - 空状态

struct EmptyStateView<IconView: View>: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @ViewBuilder let icon: () -> IconView

    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder icon: @escaping () -> IconView
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            icon()
                .padding(.bottom, Theme.Spacing.xxs)

            Text(title)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 260)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 分组标题

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.pageMargin)
    }
}

// MARK: - 反馈提示（Toast）

/// 底部玻璃胶囊提示：复制成功、删除（带撤销）等。
/// 由页面自己持有状态并决定显示时长；入场从下方弹起，退场淡出。
struct FeedbackToast: View {
    let systemImage: String
    let message: String
    var tint: Color = Theme.Palette.success
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: message)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
                .contentTransition(.numericText())

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.Palette.primary)
                        .padding(.leading, Theme.Spacing.xxs)
                        .frame(minHeight: Theme.Layout.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.92))
            }
        }
        .padding(.leading, Theme.Spacing.m)
        .padding(.trailing, actionTitle == nil ? Theme.Spacing.m : Theme.Spacing.s)
        .frame(minHeight: 48)
        .glassSurface(.capsule)
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension AnyTransition {
    /// Toast：从底部弹起 + 淡入；退场缩小淡出。
    static var toast: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.92).combined(with: .opacity)
        )
    }
}
