import SwiftUI

/// App 内语言选择页（30 种语言 / 地区，语言名用各自的文字书写）。
/// 选中立即生效，`LanguageManager.revision` 变化会让根视图重建，
/// 所有 `L10n` 计算属性随即读取新 Bundle，全文瞬间切换。
struct LanguageSelectionView: View {

    @ObservedObject private var language = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { item in
                    Button {
                        guard item != language.current else {
                            dismiss()
                            return
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(Theme.Motion.snappy) {
                            language.select(item)
                        }
                        // 稍等一拍再返回，让用户看到勾选态落在所选语言上。
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 260_000_000)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: item == language.current ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item == language.current ? Theme.Palette.primary : Theme.Palette.textSecondary.opacity(0.5))
                                .font(.system(size: 21))
                                .contentTransition(.symbolEffect(.replace))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.nativeName)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                if !item.detail.isEmpty {
                                    Text(item.detail)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.nativeName)
                    .accessibilityAddTraits(item == language.current ? [.isSelected] : [])
                }
            } header: {
                Text(L10n.Language.section)
            } footer: {
                Text(L10n.Language.footer)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(L10n.Settings.language)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
