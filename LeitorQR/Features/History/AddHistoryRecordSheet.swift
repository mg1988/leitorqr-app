import SwiftData
import SwiftUI
import UIKit

/// 手工新增历史记录弹窗
struct AddHistoryRecordSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptions: SubscriptionManager

    enum RecordKind: String, CaseIterable, Identifiable {
        case qr
        case barcode

        var id: String { rawValue }

        var title: String {
            switch self {
            case .qr: return L10n.History.Add.qr
            case .barcode: return L10n.History.Add.barcode
            }
        }
    }

    enum QRTypeOption: String, CaseIterable, Identifiable {
        case website
        case text
        case wifi
        case phone
        case email

        var id: String { rawValue }

        var title: String {
            switch self {
            case .website: return L10n.Create.typeWebsite
            case .text: return L10n.Create.typeText
            case .wifi: return L10n.Create.typeWiFi
            case .phone: return L10n.Create.typePhone
            case .email: return L10n.Create.typeEmail
            }
        }
    }

    @State private var recordKind: RecordKind = .qr
    @State private var qrType: QRTypeOption = .website
    @State private var barcodeKind: BarcodeKind = .ean13

    // 输入字段
    @State private var contentText = ""
    @State private var wifiSSID = ""
    @State private var wifiPassword = ""
    @State private var noteText = ""

    // 错误与实时预览
    @State private var previewImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                contentSection
                noteSection
                previewSection
            }
            .navigationTitle(L10n.History.Add.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Result.save) {
                        saveRecord()
                    }
                    .font(Theme.Typography.bodyEmphasis)
                    .disabled(!isValid)
                }
            }
            .onChange(of: contentText) { _, _ in updatePreview() }
            .onChange(of: wifiSSID) { _, _ in updatePreview() }
            .onChange(of: wifiPassword) { _, _ in updatePreview() }
            .onChange(of: recordKind) { _, _ in updatePreview() }
            .onChange(of: qrType) { _, _ in updatePreview() }
            .onChange(of: barcodeKind) { _, _ in updatePreview() }
        }
    }

    // MARK: - 表单分区组件

    @ViewBuilder
    private var typeSection: some View {
        Section {
            Picker(L10n.History.Add.kindCategory, selection: $recordKind) {
                ForEach(RecordKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if recordKind == .qr {
                Picker(L10n.History.Add.contentType, selection: $qrType) {
                    ForEach(QRTypeOption.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
            } else {
                Picker(L10n.History.Add.barcodeFormat, selection: $barcodeKind) {
                    ForEach(BarcodeKind.oneDimensional) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }
        } header: {
            Text(L10n.History.Add.typeSelection)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        Section {
            if recordKind == .qr && qrType == .wifi {
                TextField(L10n.History.Add.wifiSSID, text: $wifiSSID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField(L10n.History.Add.wifiPassword, text: $wifiPassword)
            } else {
                HStack {
                    TextField(placeholderForSelectedType, text: $contentText, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    // 只用 hasStrings 探测（不读内容、不触发系统"粘贴"横幅），
                    // 真正的读取放在点击动作里——在 body 里读剪贴板会每次求值都拉数据。
                    if UIPasteboard.general.hasStrings {
                        Button(L10n.History.Add.paste) {
                            contentText = UIPasteboard.general.string ?? ""
                            updatePreview()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.primary)
                        .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Text(L10n.History.Add.content)
        } footer: {
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(Theme.Palette.error)
            }
        }
    }

    @ViewBuilder
    private var noteSection: some View {
        Section {
            TextField(L10n.History.Add.notePlaceholder, text: $noteText)
        } header: {
            Text(L10n.History.Add.note)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            VStack(spacing: 12) {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: recordKind == .barcode ? .infinity : 150)
                        .frame(height: 150)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
                        Text(L10n.History.Add.previewEmpty)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text(L10n.History.Add.preview)
        }
    }

    // MARK: - 辅助计算

    private var placeholderForSelectedType: String {
        switch recordKind {
        case .qr:
            switch qrType {
            case .website: return "https://example.com"
            case .text: return L10n.Create.textPlaceholder
            case .wifi: return L10n.Create.placeholderSSID
            case .phone: return "+351 912 345 678"
            case .email: return "name@example.com"
            }
        case .barcode:
            switch barcodeKind {
            case .ean13: return "5901234123457"
            case .ean8: return "59012341"
            case .code128: return "ABC-12345"
            case .code39: return "CODE39"
            default: return "12345678"
            }
        }
    }

    private var generatedValue: String {
        if recordKind == .qr && qrType == .wifi {
            let ssid = wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ssid.isEmpty else { return "" }
            let password = wifiPassword
            var fields = "T:\(password.isEmpty ? "nopass" : "WPA");S:\(Self.escapeWiFi(ssid))"
            if !password.isEmpty {
                fields += ";P:\(Self.escapeWiFi(password))"
            }
            return "WIFI:\(fields);;"
        }
        return contentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Wi-Fi 负载里的 `\ ; , : "` 必须转义，否则 SSID 含分号会把码内容截断。
    private static func escapeWiFi(_ value: String) -> String {
        var output = ""
        for character in value {
            switch character {
            case "\\", ";", ",", ":", "\"":
                output.append("\\")
                output.append(character)
            default:
                output.append(character)
            }
        }
        return output
    }

    private var isValid: Bool {
        let value = generatedValue
        guard !value.isEmpty else { return false }
        if recordKind == .barcode {
            switch barcodeKind {
            case .ean13:
                let digits = value.filter { $0.isASCII && $0.isNumber }
                return digits.count == 12 || digits.count == 13
            case .ean8:
                let digits = value.filter { $0.isASCII && $0.isNumber }
                return digits.count == 7 || digits.count == 8
            default:
                return true
            }
        }
        return true
    }

    private func updatePreview() {
        errorMessage = nil
        let value = generatedValue
        guard !value.isEmpty else {
            previewImage = nil
            return
        }

        let kind: BarcodeKind = (recordKind == .qr) ? .qr : barcodeKind
        do {
            let img = try BarcodeImageGenerator.render(
                value: value,
                kind: kind,
                style: QRCodeStyle()
            )
            previewImage = img
        } catch {
            previewImage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveRecord() {
        let value = generatedValue
        guard !value.isEmpty else { return }

        let kind: BarcodeKind = (recordKind == .qr) ? .qr : barcodeKind
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        _ = HistoryStore.saveGenerated(
            value: value,
            kind: kind,
            note: note.isEmpty ? nil : note,
            in: modelContext,
            isPremium: subscriptions.isPremium
        )

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
