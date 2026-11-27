import Foundation
import OSLog
import SwiftData
import UIKit

/// 历史记录的读写。
///
/// 免费版只在 UI 层限制可见条数（`HistoryView.visibleRecords`），
/// 数据库**永久完整保留**所有记录，绝不物理抹除——用户续订后可立即看到全部历史。
/// 写库失败一律记录日志并把结果交给调用方提示，不用 `assertionFailure`
/// （Debug 会把「磁盘满」变成崩溃），也不用 `try?` 静默吞掉。
enum HistoryStore {

    static let freeLimit = 10

    private static let logger = Logger(subsystem: "com.leitorqr.app", category: "HistoryStore")

    /// 写入一条历史。返回是否真正落盘。
    @discardableResult
    static func save(_ content: ScanContent, in context: ModelContext, isPremium: Bool) -> Bool {
        let record = ScanRecord(content: content)
        context.insert(record)
        trim(in: context, isPremium: isPremium)
        return commit(in: context, operation: "save scan")
    }

    /// 记录一个"自己做出来的码"。生成页点 Guardar / Partilhar 时调用。
    ///
    /// 为什么不按键就写：生成是**实时**的，输入 "a"→"ab"→"abc" 会连写三条，
    /// 历史立刻被无意义的中间态塞满。只在用户明确保存/分享时落盘。
    @discardableResult
    static func saveGenerated(
        value: String,
        kind: BarcodeKind,
        note: String?,
        style: QRCodeStyle? = nil,
        logo: UIImage? = nil,
        in context: ModelContext,
        isPremium: Bool
    ) -> ScanRecord? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let content = ScanContent(
            rawValue: trimmed,
            barcodeFormat: kind.barcodeFormat,
            source: .generator
        )
        let record = ScanRecord(content: content)
        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        record.note = (cleanedNote?.isEmpty ?? true) ? nil : cleanedNote

        if let style {
            record.styleData = try? JSONEncoder().encode(style)
        }
        // 图片按 256px 存：中心图标最多只画到码边长的 22%，
        // 210pt 的码上也就 46pt，@3x 是 138px，256 已经绰绰有余。
        if let logo, let data = logo.scaledDown(to: 256).pngData() {
            record.logoData = data
        }

        context.insert(record)
        trim(in: context, isPremium: isPremium)
        return commit(in: context, operation: "save generated") ? record : nil
    }

    /// 备注就地保存。空备注会把字段清成 nil，不留空字符串。
    static func updateNote(_ text: String, on record: ScanRecord, in context: ModelContext) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        record.note = cleaned.isEmpty ? nil : cleaned
        _ = commit(in: context, operation: "update note")
    }

    /// 同一张码改了样式后再保存：更新记录里的样式，而不是又插一条一模一样的。
    static func updateStyle(
        _ style: QRCodeStyle,
        logo: UIImage?,
        on record: ScanRecord,
        in context: ModelContext
    ) {
        record.styleData = try? JSONEncoder().encode(style)
        if let logo, let data = logo.scaledDown(to: 256).pngData() {
            record.logoData = data
        } else {
            record.logoData = nil
        }
        _ = commit(in: context, operation: "update style")
    }

    /// 额度由展示层拦截，数据库层不做任何物理删除。
    static func trim(in context: ModelContext, isPremium: Bool) {
        // Intentionally left blank: soft retention, see file header.
    }

    static func delete(_ record: ScanRecord, in context: ModelContext) {
        context.delete(record)
        _ = commit(in: context, operation: "delete record")
    }

    /// 批量删除：一次 save，避免每条单独提交产生多次 SwiftData 通知与动画抖动。
    @MainActor
    static func delete(ids: Set<UUID>, in context: ModelContext) {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<ScanRecord>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        guard let matches = try? context.fetch(descriptor) else { return }
        for record in matches { context.delete(record) }
        _ = commit(in: context, operation: "delete selected")
    }

    static func clearAll(in context: ModelContext) {
        do {
            try context.delete(model: ScanRecord.self)
        } catch {
            logger.error("clear all failed: \(error.localizedDescription, privacy: .public)")
        }
        _ = commit(in: context, operation: "clear all")
    }

    static func count(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
    }

    private static func commit(in context: ModelContext, operation: String) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("\(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
