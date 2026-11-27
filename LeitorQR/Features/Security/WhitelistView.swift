import SwiftUI

/// 白名单：信任的域名不再提示风险。只存域名，不存整段 URL 或通配符。
struct WhitelistView: View {
    @State private var domains = RiskStore.whitelist
    @State private var newDomain = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(domains, id: \.self) { domain in
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(Theme.Palette.successText)
                        Text(domain)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            remove(domain)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Theme.Palette.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text(L10n.Security.whitelistSection)
            } footer: {
                Text(L10n.Security.whitelistFooter)
            }

            Section {
                HStack(spacing: Theme.Spacing.s) {
                    TextField(L10n.Security.whitelistPlaceholder, text: $newDomain)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    Button(L10n.Common.add) { add() }
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.error)
                }
            } header: {
                Text(L10n.Security.whitelistAddTitle)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .animation(Theme.Motion.smooth, value: domains)
        .sensoryFeedback(.success, trigger: domains.count) { old, new in new > old }
        .navigationTitle(L10n.Security.whitelistTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let candidate = normalize(newDomain)
        guard RiskStore.addToWhitelist(candidate) else {
            errorMessage = L10n.Security.whitelistInvalid
            return
        }
        withAnimation(Theme.Motion.smooth) {
            domains = RiskStore.whitelist
            newDomain = ""
            errorMessage = nil
        }
    }

    private func remove(_ domain: String) {
        RiskStore.removeFromWhitelist(domain)
        domains = RiskStore.whitelist
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { remove(domains[index]) }
    }

    /// 用户常整段粘贴 `https://example.com/page`，这里只留主机名。
    private func normalize(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let schemeRange = text.range(of: "://") {
            text = String(text[schemeRange.upperBound...])
        }
        if let slash = text.firstIndex(of: "/") { text = String(text[..<slash]) }
        return text
    }
}
