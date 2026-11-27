import SwiftUI
import UIKit

/// 历史里的码缩略图。
///
/// 历史只存了内容、码制与样式，图是**按需重画**的：数据库里塞 PNG 会让记录体积翻几十倍，
/// 而重画一张 40pt 的缩略图只要几毫秒。为了不让列表滚动时反复付这笔钱，用 NSCache 兜住。
struct BarcodeThumbnail: View {

    let value: String
    let kind: BarcodeKind
    var style: QRCodeStyle = QRCodeStyle()
    var logo: UIImage?
    /// 缓存键里的唯一标识，避免"同内容不同样式"的两条记录互相污染缓存。
    var cacheID: String = ""
    var side: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Palette.primary.opacity(0.12))
                    if kind.isOneDimensional {
                        BarcodeMark(kind: kind, size: side * 0.55)
                            .foregroundStyle(Theme.Palette.primary)
                    } else {
                        TabScanMark()
                            .foregroundStyle(Theme.Palette.primary)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .onAppear(perform: load)
        .accessibilityHidden(true)
    }

    private func load() {
        guard image == nil else { return }
        image = BarcodeThumbnailCache.image(
            value: value,
            kind: kind,
            style: style,
            logo: logo,
            cacheID: cacheID,
            side: side
        )
    }
}

enum BarcodeThumbnailCache {

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 16 << 20
        return cache
    }()

    static func image(
        value: String,
        kind: BarcodeKind,
        style: QRCodeStyle = QRCodeStyle(),
        logo: UIImage? = nil,
        cacheID: String = "",
        side: CGFloat
    ) -> UIImage? {
        // 样式用它的 JSON 参与键：改了颜色就是另一张图，不能命中同一条缓存。
        let styleKey = (try? JSONEncoder().encode(style)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let key = "\(cacheID)|\(kind.rawValue)|\(Int(side))|\(styleKey)|\(logo != nil)|\(value)" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        // 40pt 的列表缩略图不画模板外围装饰：画布会把二维码压到只有 26pt，
        // 变成一坨看不清的花纹。详情页的 regeneratedImage 仍带完整模板。
        // 缓存键继续用原 style，带模板和不带模板的记录不会互相命中。
        //
        // 但模板的**身份**要留住：把码画在模板的画布色上（而不是白底），
        // 列表里一眼就能认出"这条是万圣节那款"，码本身照样清晰。
        //
        // 只对**浅色画布**这么做：深色画布（万圣节、幽灵、夜空三款）的码色本身
        // 就是深色，深底深码在 40pt 上糊成一团，那种情况老老实实用白底。
        var renderStyle = style
        let template = style.template
        renderStyle.templateID = nil
        if let template, isLight(template.canvasHex) {
            renderStyle.backgroundHex = template.canvasHex
        }
        guard let full = try? BarcodeImageGenerator.render(
            value: value,
            kind: kind,
            style: renderStyle,
            logo: logo
        ) else {
            return nil
        }
        let thumb = resized(full, to: side, style: renderStyle)
        cache.setObject(thumb, forKey: key, cost: Int(side * side * 4))
        return thumb
    }

    /// 感知亮度（0–1）。浅色画布才适合拿来当缩略图底色。
    private static func isLight(_ hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.62
    }

    /// 一维码要按原比例缩到同样宽度，缩成正方形会把条码压成细线。
    /// 背景色跟样式走，否则奶油底/淡蓝底的码会被塞进一块白方块里。
    private static func resized(_ image: UIImage, to side: CGFloat, style: QRCodeStyle) -> UIImage {
        let ratio = image.size.width / max(image.size.height, 1)
        let size = ratio > 1.6
            ? CGSize(width: side, height: side / ratio)
            : CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(style.background).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
