import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// 自己画二维码。
///
/// 为什么不用 `CIFilter.qrCodeGenerator` 直接出图：它只会画黑白方块，
/// 改不了颜色、码点形状，也没法在中心留位放图标。所以这里只借用它算出**模块矩阵**，
/// 然后用 Core Graphics 重画一遍。
///
/// 两个不能省的保护：
/// - 纠错级别固定 H（约 30% 冗余），否则中心图标会把码挖坏。
/// - 三个角的定位图案单独画（外框 + 内块），不跟随码点形状——把它们也画成圆点
///   会让扫码器找不到定位角，直接认不出。
enum QRCodeRenderer {

    /// 模块边长（点数）。12 与 `QRGeneratorService` 同级，分享出去也够解码。
    private static let moduleSize: CGFloat = 12
    /// 静区 4 个模块，规范下限。
    private static let quietZone = 4

    static func render(
        value: String,
        style: QRCodeStyle,
        logo: UIImage?,
        scale: CGFloat? = nil
    ) throws -> UIImage {
        let matrix = try modules(for: value)
        let count = matrix.count
        let side = CGFloat(count + quietZone * 2) * moduleSize

        let foreground = UIColor(style.foreground)
        let background = UIColor(style.background)

        // scale 为 nil 时跟屏幕走（成品 / 分享）；缩略图传小一点的倍数，省时省内存。
        let format = UIGraphicsImageRendererFormat.default()
        if let scale { format.scale = scale }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            background.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

            // 有中心图标时，图标底下的码点直接不画（而不是画完再盖一块），液态 / 书法形的边缘才干净。
            // 纠错级别 H，挖掉 ~5% 面积完全没问题。
            let hole: CGRect? = logo == nil ? nil : logoFrame(side: side).insetBy(dx: -moduleSize * 0.35, dy: -moduleSize * 0.35)

            foreground.setFill()
            drawModules(matrix, shape: style.dotShape, hole: hole, in: ctx)
            drawFinderPatterns(
                count: count,
                frameShape: style.resolvedEyeShape,
                ballShape: style.resolvedEyeBallShape,
                frameColor: UIColor(hex: style.resolvedEyeHex),
                ballColor: UIColor(hex: style.resolvedEyeBallHex),
                background: background,
                in: ctx
            )

            if let logo {
                drawLogo(
                    logo,
                    side: side,
                    tinted: style.logoSource == .brand,
                    tile: UIColor(hex: style.logoTileHex ?? style.resolvedEyeHex),
                    background: background,
                    in: ctx
                )
            }
        }
    }

    // MARK: - 模块矩阵

    /// 从 Core Image 的输出里把点阵读出来。
    ///
    /// 不直接用 `render(_:toBitmap:)`：它的行序是 CIImage 坐标系（原点在左下），
    /// 上下颠倒后定位角会跑到左下，码就废了。这里转成 CGImage 再画进灰度位图，
    /// 行序可控，最后按 UIKit 的"第 0 行在顶部"重新排一次。
    ///
    /// **输出比真实模块数大 2**：`CIFilter.qrCodeGenerator` 在每边各留 1 模块空白。
    /// 直接把 extent 当模块数会让整码错位一个模块、定位角画到错误位置并覆盖真正的
    /// 定位角——短内容（29 模块）碰巧还能被解码器认出来，长内容（33 模块以上）
    /// 全部解不出，Wi-Fi 这类 30+ 字符的负载就全废在这里。所以必须裁掉外圈。
    private static func modules(for value: String) throws -> [[Bool]] {
        guard let data = value.data(using: .utf8) else {
            throw BarcodeGenerationError.generationFailed
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else {
            throw BarcodeGenerationError.generationFailed
        }

        let extent = output.extent.integral
        let padded = Int(extent.width)
        guard padded > 2, padded == Int(extent.height) else {
            throw BarcodeGenerationError.generationFailed
        }

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = ciContext.createCGImage(output, from: extent) else {
            throw BarcodeGenerationError.generationFailed
        }

        // 让 CGContext 自己管内存：把数组指针传进去，上下文的生命周期比那次调用长。
        guard let bitmap = CGContext(
            data: nil,
            width: padded,
            height: padded,
            bitsPerComponent: 8,
            bytesPerRow: padded,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let raw = bitmap.data else {
            throw BarcodeGenerationError.generationFailed
        }
        bitmap.interpolationQuality = .none
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: padded, height: padded))
        let pixels = raw.bindMemory(to: UInt8.self, capacity: padded * padded)

        // 跳过最外一圈 padding，只留真实模块。
        var matrix = [[Bool]]()
        matrix.reserveCapacity(padded - 2)
        for y in 1..<(padded - 1) {
            let rowStart = (padded - 1 - y) * padded
            var row = [Bool]()
            row.reserveCapacity(padded - 2)
            for x in 1..<(padded - 1) {
                row.append(pixels[rowStart + x] < 128)
            }
            matrix.append(row)
        }
        return matrix
    }

    // MARK: - 绘制

    private static func isFinderArea(x: Int, y: Int, count: Int) -> Bool {
        let inTop = y < 7
        let inBottom = y >= count - 7
        let inLeft = x < 7
        let inRight = x >= count - 7
        return (inTop && (inLeft || inRight)) || (inBottom && inLeft)
    }

    private static func rect(x: Int, y: Int) -> CGRect {
        CGRect(
            x: CGFloat(quietZone + x) * moduleSize,
            y: CGFloat(quietZone + y) * moduleSize,
            width: moduleSize,
            height: moduleSize
        )
    }

    private static func drawModules(_ matrix: [[Bool]], shape: DotShape, hole: CGRect?, in ctx: CGContext) {
        let count = matrix.count
        // 码点之间留 0.3pt 的缝，圆点和圆角才看得出来；再多会明显掉识别率。
        let gap: CGFloat = 0.3
        let m = moduleSize

        func inHole(_ x: Int, _ y: Int) -> Bool {
            guard let hole else { return false }
            return hole.intersects(rect(x: x, y: y))
        }
        func isDark(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < count, y < count else { return false }
            return matrix[y][x] && !isFinderArea(x: x, y: y, count: count) && !inHole(x, y)
        }

        for y in 0..<count {
            for x in 0..<count {
                let cell = rect(x: x, y: y)

                guard isDark(x, y) else {
                    // 液态：空格子四个角里，如果「上 / 左 / 左上」三个都是码点（L 形内角），
                    // 补一块「方块减四分之一圆」，内角就是圆滑过渡而不是直角。
                    // 只看两边不看对角会在斜向相邻处冒出十字形小尖。
                    if shape == .fluid, !isFinderArea(x: x, y: y, count: count), !inHole(x, y) {
                        drawFillets(at: cell, x: x, y: y, isDark: isDark, in: ctx)
                    }
                    continue
                }

                let up = isDark(x, y - 1), down = isDark(x, y + 1)
                let left = isDark(x - 1, y), right = isDark(x + 1, y)

                switch shape {
                case .square:
                    ctx.fill(cell.insetBy(dx: gap, dy: gap))
                case .rounded:
                    ctx.addPath(UIBezierPath(roundedRect: cell.insetBy(dx: gap, dy: gap), cornerRadius: m * 0.3).cgPath)
                    ctx.fillPath()
                case .circle:
                    ctx.fillEllipse(in: cell.insetBy(dx: gap, dy: gap))
                case .dots:
                    ctx.fillEllipse(in: cell.insetBy(dx: m * 0.1, dy: m * 0.1))
                case .fluid:
                    // 液态：只有两条相邻边都空着的那个角才是圆的（半径半个模块），其余是直角，
                    // 相邻码点自然连成一片。
                    let r = m / 2
                    ctx.addPath(cornerPath(
                        cell,
                        topLeft: (up || left) ? 0 : r,
                        topRight: (up || right) ? 0 : r,
                        bottomRight: (down || right) ? 0 : r,
                        bottomLeft: (down || left) ? 0 : r
                    ))
                    ctx.fillPath()
                case .classy:
                    // 书法形：只圆左上 / 右下两个外角，像钢笔笔触。
                    let r = m * 0.45
                    ctx.addPath(cornerPath(
                        cell,
                        topLeft: (up || left) ? 0 : r,
                        topRight: 0,
                        bottomRight: (down || right) ? 0 : r,
                        bottomLeft: 0
                    ))
                    ctx.fillPath()
                case .bars:
                    // 竖条：只和下方相邻的码点相连，形成一根根圆头胶囊。
                    let dot = cell.insetBy(dx: m * 0.09, dy: m * 0.04)
                    ctx.fillEllipse(in: dot)
                    if down {
                        ctx.fill(CGRect(x: dot.minX, y: cell.midY, width: dot.width, height: m))
                    }
                }
            }
        }
    }

    /// 液态内角过渡：在空格子的某个角画「方块减四分之一圆」。
    private static func drawFillets(
        at cell: CGRect,
        x: Int,
        y: Int,
        isDark: (Int, Int) -> Bool,
        in ctx: CGContext
    ) {
        let fr = moduleSize * 0.3
        // (角点, 水平方向, 垂直方向, 需要的三个邻居)
        let corners: [(CGPoint, CGFloat, CGFloat, (Int, Int), (Int, Int), (Int, Int))] = [
            (CGPoint(x: cell.minX, y: cell.minY), 1, 1, (0, -1), (-1, 0), (-1, -1)),
            (CGPoint(x: cell.maxX, y: cell.minY), -1, 1, (0, -1), (1, 0), (1, -1)),
            (CGPoint(x: cell.maxX, y: cell.maxY), -1, -1, (0, 1), (1, 0), (1, 1)),
            (CGPoint(x: cell.minX, y: cell.maxY), 1, -1, (0, 1), (-1, 0), (-1, 1))
        ]
        for (corner, dx, dy, a, b, c) in corners {
            guard isDark(x + a.0, y + a.1), isDark(x + b.0, y + b.1), isDark(x + c.0, y + c.1) else { continue }
            let path = CGMutablePath()
            path.move(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * fr, y: corner.y))
            // 与「角点→水平端点」「角点→垂直端点」两条边都相切的圆弧：正好是凹进去的四分之一圆。
            path.addArc(
                tangent1End: corner,
                tangent2End: CGPoint(x: corner.x, y: corner.y + dy * fr),
                radius: fr
            )
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }
    }

    /// 三个角的定位图案：外框 + 掏空 + 内块，三段式比 even-odd 路径好读，也不挑渲染器。
    /// 外框和内块的形状、颜色都可以分开设（「双色眼」）。
    private static func drawFinderPatterns(
        count: Int,
        frameShape: EyeShape,
        ballShape: EyeShape,
        frameColor: UIColor,
        ballColor: UIColor,
        background: UIColor,
        in ctx: CGContext
    ) {
        let m = moduleSize
        let eyes: [(CGPoint, EyePosition)] = [
            (CGPoint(x: quietZone, y: quietZone), .topLeft),
            (CGPoint(x: quietZone + count - 7, y: quietZone), .topRight),
            (CGPoint(x: quietZone, y: quietZone + count - 7), .bottomLeft)
        ]

        for (origin, position) in eyes {
            let outer = CGRect(x: CGFloat(origin.x) * m, y: CGFloat(origin.y) * m, width: 7 * m, height: 7 * m)

            frameColor.setFill()
            ctx.addPath(eyePath(outer, level: 0, shape: frameShape, position: position))
            ctx.fillPath()

            background.setFill()
            ctx.addPath(eyePath(outer.insetBy(dx: m, dy: m), level: 1, shape: frameShape, position: position))
            ctx.fillPath()

            ballColor.setFill()
            ctx.addPath(eyePath(outer.insetBy(dx: 2 * m, dy: 2 * m), level: 2, shape: ballShape, position: position))
            ctx.fillPath()
        }
    }

    private enum EyePosition {
        case topLeft, topRight, bottomLeft
    }

    /// 单层定位图案的轮廓。`level` 0 = 外框，1 = 掏空，2 = 内块。
    private static func eyePath(_ rect: CGRect, level: Int, shape: EyeShape, position: EyePosition) -> CGPath {
        let m = moduleSize
        let big = [2.9, 2.1, 1.25][level] * m
        let small = [0.45, 0.3, 0.22][level] * m
        switch shape {
        case .square:
            return CGPath(rect: rect, transform: nil)
        case .rounded:
            let radius = [2.0, 1.35, 0.8][level] * m
            return UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .leaf:
            // 左上角的眼：左上 + 右下大圆角；另外两个角镜像。
            return position == .topLeft
                ? cornerPath(rect, topLeft: big, topRight: small, bottomRight: big, bottomLeft: small)
                : cornerPath(rect, topLeft: small, topRight: big, bottomRight: small, bottomLeft: big)
        case .drop:
            // 水滴：朝向码中心的那个角是小角，其余三个大圆角。
            switch position {
            case .topLeft:
                return cornerPath(rect, topLeft: big, topRight: big, bottomRight: small, bottomLeft: big)
            case .topRight:
                return cornerPath(rect, topLeft: big, topRight: big, bottomRight: big, bottomLeft: small)
            case .bottomLeft:
                return cornerPath(rect, topLeft: big, topRight: small, bottomRight: big, bottomLeft: big)
            }
        }
    }

    /// 四个角分别指定圆角半径的矩形。
    private static func cornerPath(
        _ r: CGRect,
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomRight: CGFloat,
        bottomLeft: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX + topLeft, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - topRight, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + topRight), radius: topRight)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bottomRight))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - bottomRight, y: r.maxY), radius: bottomRight)
        path.addLine(to: CGPoint(x: r.minX + bottomLeft, y: r.maxY))
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - bottomLeft), radius: bottomLeft)
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + topLeft))
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + topLeft, y: r.minY), radius: topLeft)
        path.closeSubpath()
        return path
    }

    /// 中心图标占的方块（边长 = 码宽的 20%）。
    private static func logoFrame(side: CGFloat) -> CGRect {
        let box = side * 0.2
        return CGRect(x: (side - box) / 2, y: (side - box) / 2, width: box, height: box)
    }

    /// 中心图标：圆角方块。
    /// - 品牌图标（`tinted`）：底下一块定位角强调色的「App 图标」方块，图标染成白色——和精选样式的双色眼呼应。
    /// - 用户照片：背景色底 + 照片按圆角方块裁切（aspect fill），照片再大也不会破坏轮廓。
    private static func drawLogo(
        _ logo: UIImage,
        side: CGFloat,
        tinted: Bool,
        tile: UIColor,
        background: UIColor,
        in ctx: CGContext
    ) {
        let frame = logoFrame(side: side)

        background.setFill()
        ctx.addPath(UIBezierPath(roundedRect: frame, cornerRadius: frame.width * 0.28).cgPath)
        ctx.fillPath()

        let inner = frame.insetBy(dx: frame.width * 0.11, dy: frame.width * 0.11)
        let innerPath = UIBezierPath(roundedRect: inner, cornerRadius: inner.width * 0.26).cgPath

        if tinted {
            tile.setFill()
            ctx.addPath(innerPath)
            ctx.fillPath()

            let glyph = inner.insetBy(dx: inner.width * 0.2, dy: inner.height * 0.2)
            whiteGlyph(logo).draw(in: aspectFit(logo.size, in: glyph))
        } else {
            ctx.saveGState()
            ctx.addPath(innerPath)
            ctx.clip()
            drawAspectFill(logo, in: inner, in: ctx)
            ctx.restoreGState()
        }
    }

    /// 把图标按自身透明度染成纯白（白底 + destinationIn），不依赖图片的 renderingMode。
    private static func whiteGlyph(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero, blendMode: .destinationIn, alpha: 1)
        }
    }

    private static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }

    /// 等比放大到铺满目标矩形再居中裁掉溢出部分（相当于 `scaledToFill` + `clipped`）。
    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, in ctx: CGContext) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: rect.midX - drawn.width / 2,
            y: rect.midY - drawn.height / 2
        )
        image.draw(in: CGRect(origin: origin, size: drawn))
    }
}
