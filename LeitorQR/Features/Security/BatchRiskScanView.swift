import PhotosUI
import SwiftData
import SwiftUI

struct BatchScanItem: Identifiable {
    let id = UUID()
    let fileName: String
    let results: [BatchFinding]
}

struct BatchFinding: Identifiable {
    let id = UUID()
    let host: String
    let level: QRRiskLevel
    let findingKeys: [String]
    let trusted: Bool
}

/// 批量图片核对：从相册选多张图，逐张识别其中的网址并就地分析，纯端侧。
struct BatchRiskScanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var reports: [BatchScanItem] = []
    @State private var isProcessing = false
    @State private var statusMessage: String?

    private let imageScanner = ImageScannerService()

    var body: some View {
        Group {
            if reports.isEmpty && !isProcessing {
                VStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Palette.primary.opacity(0.7))
                    Text(L10n.Security.batchEmptyTitle)
                        .font(Theme.Typography.sectionTitle)
                    Text(L10n.Security.batchEmptyDesc)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        Label(L10n.Security.batchPick, systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if let statusMessage {
                        Text(statusMessage)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.error)
                    }
                }
                .padding(Theme.Spacing.xl)
            } else {
                List {
                    if isProcessing {
                        HStack {
                            ProgressView()
                            Text(L10n.Security.batchProcessing)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    ForEach(reports) { report in
                        Section {
                            ForEach(report.results) { finding in
                                findingRow(finding)
                            }
                        } header: {
                            Text(report.fileName)
                        }
                    }
                }
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label(L10n.Security.batchPickMore, systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(Theme.Spacing.m)
            }
        }
        .navigationTitle(L10n.Security.batchTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: pickerItems) {
            guard !pickerItems.isEmpty else { return }
            await process(pickerItems)
            pickerItems = []
        }
    }

    private func findingRow(_ finding: BatchFinding) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(color(for: finding.level))
                    .frame(width: 8, height: 8)
                Text(finding.host)
                    .font(Theme.Typography.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if finding.trusted {
                    Text(L10n.Security.batchTrusted)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.success)
                } else {
                    Text(label(for: finding.level))
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(color(for: finding.level))
                }
            }
            if !finding.findingKeys.isEmpty && !finding.trusted {
                Text(finding.findingKeys.map { L10n.Risk.finding(forKey: $0) }.joined(separator: " · "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private func process(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        statusMessage = nil
        defer { isProcessing = false }
        var newReports: [BatchScanItem] = []
        var urlCount = 0

        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let contents = try? await imageScanner.scan(image: image) else { continue }

            var findings: [BatchFinding] = []
            for content in contents {
                guard content.type == .url, let url = content.openableURL else { continue }
                let trusted = RiskStore.isTrusted(url.host ?? "")
                let assessment = QRRiskAnalyzer.analyze(url)
                findings.append(BatchFinding(
                    host: url.host ?? url.absoluteString,
                    level: assessment.level,
                    findingKeys: assessment.findings.map(\.key),
                    trusted: trusted
                ))
                // 批量结果同样落库，和单张扫描共用核对历史。
                RiskStore.record(assessment: assessment, url: url, in: modelContext)
                urlCount += 1
            }
            if !findings.isEmpty {
                newReports.append(BatchScanItem(
                    fileName: String(format: L10n.Security.batchImageName, index + 1),
                    results: findings
                ))
            }
        }

        reports.append(contentsOf: newReports)
        if urlCount == 0 {
            statusMessage = L10n.Security.batchNoURL
        }
    }

    private func color(for level: QRRiskLevel) -> Color {
        switch level {
        case .low: return Theme.Palette.success
        case .medium: return Theme.Palette.warning
        case .high: return Theme.Palette.error
        }
    }

    private func label(for level: QRRiskLevel) -> String {
        switch level {
        case .low: return L10n.Result.riskLow
        case .medium: return L10n.Result.riskMedium
        case .high: return L10n.Result.riskHigh
        }
    }
}
