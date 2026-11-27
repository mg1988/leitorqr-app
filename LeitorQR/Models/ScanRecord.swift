import Foundation
import SwiftData
import UIKit

/// 本地扫描历史（SwiftData）。数据只存在本机，不上传。
@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var rawValue: String
    var contentTypeRaw: String
    var barcodeFormatRaw: String?
    var sourceRaw: String
    var createdAt: Date
    var title: String?
    /// 用户自己写的备注。扫来的和生成的都能备注，空字符串一律当没有。
    var note: String?
    /// 生成这张码时用的样式（JSON）。扫来的记录为 nil，用默认样式重画。
    var styleData: Data?
    /// 中心图标的位图。品牌图标是渲染好的小 PNG，用户图片是压到 256px 的版本；
    /// 走 `externalStorage`，别把几百 KB 塞进数据库行里。
    @Attribute(.externalStorage) var logoData: Data?

    init(
        id: UUID = UUID(),
        rawValue: String,
        contentType: ScanContentType,
        barcodeFormat: BarcodeFormat?,
        source: ScanSource,
        createdAt: Date = Date(),
        title: String? = nil,
        note: String? = nil,
        styleData: Data? = nil,
        logoData: Data? = nil
    ) {
        self.id = id
        self.rawValue = rawValue
        self.contentTypeRaw = contentType.rawValue
        self.barcodeFormatRaw = barcodeFormat?.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.title = title
        self.note = note
        self.styleData = styleData
        self.logoData = logoData
    }

    convenience init(content: ScanContent, createdAt: Date = Date()) {
        self.init(
            rawValue: content.rawValue,
            contentType: content.type,
            barcodeFormat: content.barcodeFormat,
            source: content.source,
            createdAt: createdAt,
            title: content.displayHost
        )
    }

    var contentType: ScanContentType {
        ScanContentType(rawValue: contentTypeRaw) ?? .text
    }

    var barcodeFormat: BarcodeFormat? {
        barcodeFormatRaw.flatMap(BarcodeFormat.init(rawValue:))
    }

    var source: ScanSource {
        ScanSource(rawValue: sourceRaw) ?? .camera
    }

    /// 列表主标题：网址显示域名，其余显示类型名——内容本身留给副标题，避免同一行重复两次同样的文字。
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return contentType.localizedName }
        return contentType == .url ? trimmed : contentType.localizedName
    }

    /// 列表副标题：内容预览，过长由 UI 截断。
    /// 结构化负载（Wi-Fi / 名片）交给 `readableSummary` 提炼成一句人话。
    var displaySubtitle: String {
        asContent.readableSummary
    }

    /// 去掉首尾空白后的备注；全空白视为没有备注。
    var trimmedNote: String? {
        guard let note else { return nil }
        let value = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// 生成这条记录的码制。只有本地能重画的格式才有值（UPC-E / Data Matrix 没有）。
    var regenerableKind: BarcodeKind? {
        barcodeFormat?.barcodeKind
    }

    /// 当时用的样式。解码失败（旧版本写的、或数据损坏）就退回默认样式，
    /// 让图还能画出来，而不是整条记录变空白。
    var savedStyle: QRCodeStyle {
        guard let styleData,
              let style = try? JSONDecoder().decode(QRCodeStyle.self, from: styleData) else {
            return QRCodeStyle()
        }
        return style
    }

    var savedLogo: UIImage? {
        logoData.flatMap(UIImage.init(data:))
    }

    /// 用记录里存的样式把这张码重画出来，历史列表与详情靠它显示"是这个码"。
    var regeneratedImage: UIImage? {
        guard let kind = regenerableKind else { return nil }
        // 模板码图是原生 3x（约 2800px），列表 contextMenu 每次求值都会访问它。
        // 按「记录 id + 样式 + 图标」缓存，避免滚动时反复全量重画。
        let styleKey = styleData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let key = "\(id.uuidString)|\(styleKey)|\(logoData?.count ?? 0)|\(rawValue)" as NSString
        if let hit = RegeneratedImageCache.images.object(forKey: key) { return hit }
        guard let rendered = try? BarcodeImageGenerator.render(
            value: rawValue,
            kind: kind,
            style: savedStyle,
            logo: savedLogo
        ) else { return nil }
        let pixels = rendered.size.width * rendered.size.height * rendered.scale * rendered.scale
        RegeneratedImageCache.images.setObject(rendered, forKey: key, cost: Int(pixels * 4))
        return rendered
    }

    /// 还原为可展示的扫描内容（历史详情复用结果页）。
    /// 类型用入库时的判断，避免 `detect` 规则调整后旧记录的类型/摘要/操作跟着漂移。
    var asContent: ScanContent {
        ScanContent(
            rawValue: rawValue,
            type: contentType,
            barcodeFormat: barcodeFormat,
            source: source
        )
    }
}


/// 全尺寸码图缓存放在模型外，避免 @Model 宏展开时遇到静态存储属性。
private enum RegeneratedImageCache {
    static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 32 << 20
        return cache
    }()
}
