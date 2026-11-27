import SwiftData
import SwiftUI

/// 核对历史：只存本机。付费权益，入口处已做门控。
struct RiskHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RiskScanRecord.createdAt, order: .reverse) private var records: [RiskScanRecord]

    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    L10n.Security.historyEmptyTitle,
                    systemImage: "shield.checkered",
                    description: Text(L10n.Security.historyEmptyDesc)
                )
            } else {
                List {
                    Section {
                        ForEach(records) { record in
                            riskRow(record)
                        }
                        .onDelete(perform: delete)
                    } header: {
                        Text(String(format: L10n.Security.historyCount, records.count))
                    }
                }
            }
        }
        .navigationTitle(L10n.Security.historyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Security.clear, role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
        }
        .confirmationDialog(L10n.Security.clearConfirmTitle, isPresented: $showClearConfirm) {
            Button(L10n.Security.clear, role: .destructive) {
                RiskStore.clearHistory(in: modelContext)
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Security.clearConfirmMessage)
        }
    }

    private func riskRow(_ record: RiskScanRecord) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(levelColor(record.level))
                    .frame(width: 8, height: 8)
                Text(record.host)
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(levelLabel(record.level))
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(levelColor(record.level))
            }
            Text(record.rawValue)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
            if !record.findingKeys.isEmpty {
                Text(record.findingKeys.map { L10n.Risk.finding(forKey: $0) }.joined(separator: " · "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
        try? modelContext.save()
    }

    private func levelColor(_ level: QRRiskLevel) -> Color {
        switch level {
        case .low: return Theme.Palette.success
        case .medium: return Theme.Palette.warning
        case .high: return Theme.Palette.error
        }
    }

    private func levelLabel(_ level: QRRiskLevel) -> String {
        switch level {
        case .low: return L10n.Result.riskLow
        case .medium: return L10n.Result.riskMedium
        case .high: return L10n.Result.riskHigh
        }
    }
}
