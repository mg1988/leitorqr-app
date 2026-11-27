import SwiftData
import SwiftUI
import UIKit

/// 历史详情：码图 + 备注 + 内容操作 + 记录删除。
struct HistoryDetailView: View {

    let record: ScanRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var codeImage: UIImage?
    @State private var didSavePhoto = false
    @State private var message: String?
    @State private var showDeleteConfirm = false
    /// 备注是边打边存的，用任务把连续输入合并成一次写库。
    @State private var noteSaveTask: Task<Void, Never>?
    /// 删除后 onDisappear 不能再对已删除的 @Model 写备注。
    @State private var didDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                codeCard
                noteCard
                ScanResultContent(content: record.asContent, canRescan: false)
                deleteButton
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.m)
        }
        .screenBackground()
        .dismissKeyboardOnTap()
        .keyboardDoneButton()
        .navigationTitle(L10n.History.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Palette.error)
                }
                .accessibilityLabel(L10n.Common.delete)
            }
        }
        .alert(L10n.History.deleteConfirmTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                didDelete = true
                noteSaveTask?.cancel()
                HistoryStore.delete(record, in: modelContext)
                dismiss()
            }
        } message: {
            Text(L10n.History.deleteConfirmMessage)
        }
        .onAppear {
            noteText = record.note ?? ""
            codeImage = record.regeneratedImage
        }
        .onDisappear {
            noteSaveTask?.cancel()
            guard !didDelete else { return }
            HistoryStore.updateNote(noteText, on: record, in: modelContext)
        }
    }

    // MARK: - 码图

    @ViewBuilder
    private var codeCard: some View {
        if let codeImage {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                sectionTitle(L10n.History.codeTitle)

                Image(uiImage: codeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: record.barcodeFormat?.isTwoDimensional == false ? .infinity : 220)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                HStack(spacing: Theme.Spacing.s) {
                    Button {
                        savePhoto(codeImage)
                    } label: {
                        Label(
                            L10n.Result.save,
                            systemImage: didSavePhoto ? "checkmark" : "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    ShareLink(
                        item: Image(uiImage: codeImage),
                        preview: SharePreview(record.displayTitle, image: Image(uiImage: codeImage))
                    ) {
                        Label(L10n.Result.share, systemImage: "square.and.arrow.up")
                            .font(Theme.Typography.button)
                            .foregroundStyle(Theme.Palette.primary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .fill(Theme.Palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
                            )
                    }
                }

                if let message {
                    Text(message)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                InfoCircleMark(size: 15)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(L10n.History.noCodeImage)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s)
            .background(
                Theme.Palette.border.opacity(0.25),
                in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
            )
        }
    }

    // MARK: - 备注

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(L10n.History.noteLabel)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            TextField(L10n.History.notePlaceholder, text: $noteText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1...4)
                .onChange(of: noteText) { _, value in
                    scheduleNoteSave(value)
                }

            Text(L10n.History.noteHint)
                .font(.caption2)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 删除按钮

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text(L10n.History.deleteRecord)
            }
            .font(Theme.Typography.button)
            .foregroundStyle(Theme.Palette.error)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Palette.error.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.Palette.error.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
        .padding(.top, Theme.Spacing.xs)
    }

    private func scheduleNoteSave(_ value: String) {
        guard !didDelete else { return }
        noteSaveTask?.cancel()
        noteSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            HistoryStore.updateNote(value, on: record, in: modelContext)
        }
    }

    private func savePhoto(_ image: UIImage) {
        message = nil
        PhotoLibrary.save(image) { success in
            if success {
                didSavePhoto = true
            } else {
                message = L10n.Create.saveFailed
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}
