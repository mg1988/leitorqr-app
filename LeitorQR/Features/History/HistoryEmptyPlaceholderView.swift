import SwiftUI

/// 历史记录空状态。
///
/// 设计原则：不用渐变、呼吸光环、激光扫描线和星芒装饰。
/// 用一组安静的层次卡片表达「记录会堆在这里」，主行动沿用全局玻璃主按钮。
struct HistoryEmptyPlaceholderView: View {

    var onAddTap: () -> Void

    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.l) {
                illustration
                    .scaleEffect(isRevealed ? 1 : 0.94)
                    .opacity(isRevealed ? 1 : 0)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(L10n.History.emptyTitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)

                    Text(L10n.History.emptyMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 300)
                }

                actions
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, Theme.Spacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.04)) {
                isRevealed = true
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            GlassPrimaryButton(
                title: L10n.History.scanNow,
                systemImage: "qrcode.viewfinder"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                NotificationCenter.default.post(name: .switchToScanTab, object: nil)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAddTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .medium))
                    Text(L10n.History.manualEntry)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
    }

    // MARK: - Illustration

    private var illustration: some View {
        Image("HistoryEmptyArt")
            .resizable()
            .scaledToFit()
            .frame(width: 164, height: 154)
            // 用户素材本身是白色文件夹，压在浅灰页面上几乎融掉；
            // 用跟随 alpha 轮廓的柔和投影拉开层次，不改图标本体。
            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
            .accessibilityHidden(true)
    }
}

// MARK: - 搜索无结果占位图

struct SearchEmptyStateView: View {

    let query: String
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(light: 0xF1F5F9, dark: 0x1E2430))
                    .frame(width: 96, height: 96)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            VStack(spacing: 8) {
                Text(L10n.History.searchEmptyTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text(L10n.History.searchEmptyMessage(query))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button(action: onClear) {
                Text(L10n.History.clearSearch)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Theme.Palette.primary.opacity(0.12))
                    )
            }
            .buttonStyle(PressScaleStyle())

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
