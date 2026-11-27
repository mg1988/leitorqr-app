import UIKit

/// 把二维码合成进「模板卡片」。
///
/// 三条硬约束：
/// 1. **码图 1:1 贴入，绝不缩放**。非整数倍缩放会把模块边缘糊掉，短码当场扫不出来
///    （项目里已经踩过 EAN-8 的坑）。外围画布尺寸由码图尺寸推算，而不是反过来把码缩到画布里。
/// 2. **装饰永远画在白卡之外**。用 even-odd 裁剪把白卡从绘制区域里挖掉，
///    就算元素坐标算偏了也不会盖住一个模块。装饰只是气氛，不能吃可扫性。
/// 3. **少而大**。第一版每款撒十几个小元素，结果在 160pt 的网格缩略图里
///    全变成 2–3px 的碎点，12 款看起来一模一样。现在每款只留 1–3 个主元素，
///    半径按画布 0.08 量级画，保证缩略图里也能一眼认出是南瓜还是雪花。
///
/// 所有装饰都是 Core Graphics 自绘的几何图形，不依赖任何图片素材，
/// 因此历史里只存 `templateID` 就能逐像素重画出同一张图。
enum TemplateRenderer {

    static func compose(code: UIImage, template: CodeTemplate) -> UIImage {
        let side = code.size.width
        guard side > 0 else { return code }

        // 画布比码边长 2.0 倍：白卡占 60%，四周留出足够宽的环带放装饰。
        // 第一版只留 28%（1.56 倍），装饰全挤在缝里，缩略图上根本看不清。
        let outer = side * 0.50
        let canvasSide = side + outer * 2
        let canvas = CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide)

        // 白卡边距 10% 码边长。这不是审美参数，是**能不能被扫出来**的参数：
        // 码图自带 4 个模块的静区（约 10%），白卡再包 10%，才是连续约 20% 的浅色区。
        // 只留 5% 时，深色画布上 Vision 直接检不出（实测深色环带 + 5% 白卡 = 0 检出，
        // 白卡加宽到 10% 立刻恢复；浅色画布因为画布本身也是白的才侥幸通过）。
        // 白卡跟着变大，画布也同步放大到 2.0 倍，否则装饰会被白卡压掉一圈。
        let cardPad = side * 0.10
        let cardSide = side + cardPad * 2
        let cardRect = CGRect(
            x: (canvasSide - cardSide) / 2,
            y: (canvasSide - cardSide) / 2,
            width: cardSide,
            height: cardSide
        )
        let cardPath = UIBezierPath(
            roundedRect: cardRect,
            cornerRadius: side * 0.085
        ).cgPath

        let format = UIGraphicsImageRendererFormat.default()
        // 渲染器必须跟码图**原生分辨率**一致。之前固定 scale = 1，等于把 3x 的码图
        // 降采样 3 倍再贴进去：0.3pt 的模块缝被平均掉、圆角被抹平，
        // Vision 在深色画布上直接检不出（同一张码裁出来单独解是好的）。
        // 用码图自己的 scale，绘制区域就是它的原生像素尺寸，这才叫真正的 1:1。
        format.scale = code.scale > 0 ? code.scale : UIScreen.main.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas.size, format: format).image { rendererContext in
            let ctx = rendererContext.cgContext

            UIColor(hex: template.canvasHex).setFill()
            ctx.fill(canvas)

            // 装饰：even-odd 把白卡挖空，装饰只落在外围。
            ctx.saveGState()
            let outside = UIBezierPath(rect: canvas)
            outside.append(UIBezierPath(cgPath: cardPath))
            outside.usesEvenOddFillRule = true
            outside.addClip()
            drawDecoration(
                template.decoration,
                in: ctx,
                canvas: canvas,
                palette: Palette(template: template)
            )
            ctx.restoreGState()

            // 白卡：带一层柔和投影，卡片才有"浮在画布上"的层次（漫画风保留扁平实边）。
            ctx.saveGState()
            if template.decoration != .comicBubble {
                ctx.setShadow(
                    offset: CGSize(width: 0, height: side * 0.008),
                    blur: side * 0.022,
                    color: UIColor.black.withAlphaComponent(0.20).cgColor
                )
            }
            UIColor(hex: template.cardHex).setFill()
            ctx.addPath(cardPath)
            ctx.fillPath()
            ctx.restoreGState()

            ctx.addPath(cardPath)
            if template.decoration == .comicBubble {
                ctx.setStrokeColor(UIColor(hex: 0x18181B).cgColor)
                ctx.setLineWidth(max(2.5, side * 0.016))
            } else {
                ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
                ctx.setLineWidth(max(1, side * 0.004))
            }
            ctx.strokePath()

            // 1:1，与 QRCodeRenderer 输出的每个模块像素对齐。
            code.draw(in: CGRect(
                x: (canvasSide - side) / 2,
                y: (canvasSide - side) / 2,
                width: side,
                height: side
            ))
        }
    }

    // MARK: - 调色

    private struct Palette {
        let primary: UIColor
        let secondary: UIColor
        let ink: UIColor
        /// 永远是深色。`ink` 会随画布明暗翻转，但南瓜的脸、幽灵的眼睛这类
        /// "必须在浅色图形上挖出深色"的元素不能翻——翻成白色就等于没画。
        let deep: UIColor
        let light: UIColor

        init(template: CodeTemplate) {
            primary = UIColor(hex: template.accentHex)
            secondary = UIColor(hex: template.accentSecondaryHex)
            // 深色画布上用浅色当"墨"，浅色画布上用深色。眼睛/轮廓都得看得见。
            let isDarkCanvas = TemplateRenderer.isDark(template.canvasHex)
            ink = isDarkCanvas ? UIColor(hex: 0xF5F7FC) : UIColor(hex: 0x2B2333)
            deep = UIColor(hex: 0x2B2333)
            light = UIColor.white
        }
    }

    private static func isDark(_ hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xFF)
        let g = Double((hex >> 8) & 0xFF)
        let b = Double(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 110
    }

    // MARK: - 布局辅助（归一化坐标 → 画布坐标）

    private static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    private static func radius(_ scale: CGFloat, in rect: CGRect) -> CGFloat {
        scale * rect.width
    }

    /// (x, y, 半径比例, 用主色还是辅色)
    private typealias Spec = (CGFloat, CGFloat, CGFloat, Bool)

    /// 对角两组主位。每款模板的核心元素放这里——缩略图里先看到的就是它们。
    private static let diagonalA: [Spec] = [
        (0.112, 0.112, 0.078, true),
        (0.888, 0.888, 0.078, true)
    ]

    private static let diagonalB: [Spec] = [
        (0.888, 0.112, 0.078, false),
        (0.112, 0.888, 0.078, false)
    ]

    /// 角落主位：四个角的中心点。半径上限约 0.08，再大就会压到白卡被裁掉。
    private static let cornerSpecs: [Spec] = [
        (0.112, 0.112, 0.078, true),
        (0.888, 0.112, 0.078, false),
        (0.112, 0.888, 0.078, false),
        (0.888, 0.888, 0.078, true)
    ]

    /// 边中位：上/下/左/右。半径比角位小一圈，避免顶到画布边。
    private static let edgeSpecs: [Spec] = [
        (0.500, 0.062, 0.055, false),
        (0.500, 0.938, 0.055, true),
        (0.062, 0.500, 0.055, true),
        (0.938, 0.500, 0.055, false)
    ]

    private static func place(
        _ specs: [Spec],
        in rect: CGRect,
        ctx: CGContext,
        palette: Palette,
        draw: (CGPoint, CGFloat, UIColor, CGContext) -> Void
    ) {
        for (x, y, scale, usePrimary) in specs {
            draw(
                point(x, y, in: rect),
                radius(scale, in: rect),
                usePrimary ? palette.primary : palette.secondary,
                ctx
            )
        }
    }

    // MARK: - 装饰分派

    private static func drawDecoration(
        _ decoration: TemplateDecoration,
        in ctx: CGContext,
        canvas: CGRect,
        palette: Palette
    ) {
        switch decoration {
        case .none:
            break

        case .dots:
            place(cornerSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dotGrid(at: c, r: r, color: color, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dotGrid(at: c, r: r * 0.7, color: color, in: g)
            }

        case .sparkles:
            place(cornerSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                sparkle(at: c, r: r, color: color, in: g)
            }

        case .stars:
            place(cornerSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                star(at: c, r: r, color: color, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.34, color: color, in: g)
            }

        case .confetti:
            let specs: [Spec] = [
                (0.108, 0.112, 0.062, true), (0.888, 0.112, 0.058, false),
                (0.108, 0.888, 0.056, false), (0.888, 0.888, 0.064, true),
                (0.500, 0.060, 0.052, false), (0.500, 0.940, 0.056, true),
                (0.060, 0.500, 0.050, false), (0.940, 0.500, 0.054, true)
            ]
            var index = 0
            for (x, y, scale, usePrimary) in specs {
                let color = usePrimary ? palette.primary : palette.secondary
                let center = point(x, y, in: canvas)
                let r = radius(scale, in: canvas)
                // 圆片与三角旗混着撒，全是方块看着像碎纸屑。
                if index % 2 == 0 {
                    confettiDisc(at: center, r: r, color: color, in: ctx)
                } else {
                    confettiFlag(
                        at: center,
                        r: r,
                        angle: CGFloat(index) * 0.62,
                        color: color,
                        in: ctx
                    )
                }
                index += 1
            }

        case .pumpkin:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, _, g in
                pumpkin(at: c, r: r, palette: palette, in: g)
            }
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, _, g in
                bat(at: c, r: r, color: palette.ink, palette: palette, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.3, color: color, in: g)
            }

        case .ghost:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                ghost(at: c, r: r, color: color, palette: palette, in: g)
            }
            // 蜘蛛网贴在画布真正的角上，半藏在卡片后面。
            web(at: point(0, 0, in: canvas), r: radius(0.10, in: canvas), color: palette.secondary, in: ctx)
            web(at: point(1, 1, in: canvas), r: radius(0.10, in: canvas), color: palette.secondary, in: ctx, flip: true)
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.28, color: color, in: g)
            }

        case .snow:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                snowflake(at: c, r: r, color: color, in: g)
            }
            // 次对角线原本画礼物盒，红色落在薄荷底上像 bug，改成松树。
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                pineTree(at: c, r: r * 0.86, color: color, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.26, color: color, in: g)
            }

        case .rose:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                rose(at: c, r: r, color: color, palette: palette, in: g)
            }
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, _, g in
                rose(at: c, r: r * 0.82, color: palette.secondary, palette: palette, in: g)
            }

        case .hearts:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                heart(at: c, r: r, color: color, in: g)
            }
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                heart(at: c, r: r * 0.76, color: color, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.36, color: color, in: g)
            }

        case .balloons:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                balloon(at: c, r: r, color: color, palette: palette, in: g)
            }
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                balloon(at: c, r: r * 0.84, color: color, palette: palette, in: g)
            }
            bunting(in: canvas, palette: palette, ctx: ctx)

        case .gift:
            place(diagonalA, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                gift(at: c, r: r, color: color, palette: palette, in: g)
            }
            place(diagonalB, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                star(at: c, r: r * 0.82, color: color, in: g)
            }
            place(edgeSpecs, in: canvas, ctx: ctx, palette: palette) { c, r, color, g in
                dot(at: c, r: r * 0.28, color: color, in: g)
            }

        case .comicBubble:
            comicBubble(
                in: canvas,
                side: canvas.width / 2.0,
                cardRect: CGRect(
                    x: (canvas.width - canvas.width * 0.60) / 2,
                    y: (canvas.height - canvas.height * 0.60) / 2,
                    width: canvas.width * 0.60,
                    height: canvas.height * 0.60
                ),
                palette: palette,
                in: ctx
            )
        }
    }

    // MARK: - 图元

    private static func fill(_ path: CGPath, _ color: UIColor, in ctx: CGContext) {
        color.setFill()
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func dot(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        color.setFill()
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// 五角星：实心 + 内部高光小三角，避免一大坨死色。
    private static func star(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        let path = CGMutablePath()
        for i in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rad = i % 2 == 0 ? r : r * 0.46
            let p = CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        fill(path, color, in: ctx)

        let inner = CGMutablePath()
        let ir = r * 0.26
        for i in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rad = i % 2 == 0 ? ir : ir * 0.46
            let p = CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad)
            i == 0 ? inner.move(to: p) : inner.addLine(to: p)
        }
        inner.closeSubpath()
        fill(inner, UIColor.white.withAlphaComponent(0.55), in: ctx)
    }

    /// 四角星：四个长尖 + 四个内凹点，比圆点更像"闪光"。
    private static func sparkle(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        let path = CGMutablePath()
        for i in 0..<8 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 4
            let rad = i % 2 == 0 ? r : r * 0.24
            let p = CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        fill(path, color, in: ctx)
    }

    /// 爱心：上宽下尖的经典比例，填充用主色→辅色的线性渐变。
    private static func heart(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y + r))
        p.addCurve(
            to: CGPoint(x: c.x - r, y: c.y - r * 0.25),
            control1: CGPoint(x: c.x - r * 0.12, y: c.y + r * 0.48),
            control2: CGPoint(x: c.x - r, y: c.y + r * 0.12)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y - r * 0.38),
            control1: CGPoint(x: c.x - r, y: c.y - r * 0.78),
            control2: CGPoint(x: c.x - r * 0.42, y: c.y - r * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: c.x + r, y: c.y - r * 0.25),
            control1: CGPoint(x: c.x + r * 0.42, y: c.y - r * 0.82),
            control2: CGPoint(x: c.x + r, y: c.y - r * 0.78)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y + r),
            control1: CGPoint(x: c.x + r, y: c.y + r * 0.12),
            control2: CGPoint(x: c.x + r * 0.12, y: c.y + r * 0.48)
        )
        p.closeSubpath()

        // 纯色填充（11-27 去掉渐变）。只画在白卡之外的装饰区，不影响码区。
        ctx.saveGState()
        color.withAlphaComponent(0.9).setFill()
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()

        // 高光：一小片斜白，体积感立刻出来。
        UIColor.white.withAlphaComponent(0.45).setFill()
        ctx.fillEllipse(in: CGRect(
            x: c.x - r * 0.52,
            y: c.y + r * 0.02,
            width: r * 0.34,
            height: r * 0.5
        ))
    }

    /// 彩纸圆片。
    private static func confettiDisc(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        color.setFill()
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.62, width: r * 1.24, height: r * 1.24))
    }

    /// 小三角旗，带一点旋转。
    private static func confettiFlag(
        at c: CGPoint, r: CGFloat, angle: CGFloat, color: UIColor, in ctx: CGContext
    ) {
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: angle)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -r * 0.52, y: -r * 0.92))
        p.addLine(to: CGPoint(x: r * 0.92, y: -r * 0.36))
        p.addLine(to: CGPoint(x: -r * 0.52, y: r * 0.24))
        p.closeSubpath()
        fill(p, color, in: ctx)
        ctx.restoreGState()
    }

    /// 3×3 波点：克制的小圆点阵，用来跟"闪光""星星"区分开。
    private static func dotGrid(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        color.setFill()
        let pr = r * 0.12
        let step = r * 0.48
        for row in -1...1 {
            for col in -1...1 {
                let x = c.x + CGFloat(col) * step
                let y = c.y + CGFloat(row) * step
                ctx.fillEllipse(in: CGRect(x: x - pr, y: y - pr, width: pr * 2, height: pr * 2))
            }
        }
    }

    /// 玫瑰：外层五瓣 + 内层五瓣（错开半角）+ 花心。
    ///
    /// 几何自绘里最容易画得像花的一种——绕中心旋转椭圆就有花瓣轮廓。
    /// 试过用缎带做 love-rose，描边出来的 S 形始终像一根扭面条，放弃。
    private static func rose(
        at c: CGPoint, r: CGFloat, color: UIColor, palette: Palette, in ctx: CGContext
    ) {
        // 外层花瓣
        for i in 0..<5 {
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: CGFloat(i) * 2 * .pi / 5)
            color.setFill()
            let w = r * 0.80
            let h = r * 0.94
            ctx.fillEllipse(in: CGRect(x: -w / 2, y: -h, width: w, height: h))
            ctx.restoreGState()
        }

        // 内层花瓣：错开半角、收小，用辅色
        for i in 0..<5 {
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .pi / 5 + CGFloat(i) * 2 * .pi / 5)
            palette.secondary.setFill()
            let w = r * 0.50
            let h = r * 0.60
            ctx.fillEllipse(in: CGRect(x: -w / 2, y: -h, width: w, height: h))
            ctx.restoreGState()
        }

        // 花心
        palette.deep.withAlphaComponent(0.8).setFill()
        ctx.fillEllipse(in: CGRect(
            x: c.x - r * 0.22,
            y: c.y - r * 0.22,
            width: r * 0.44,
            height: r * 0.44
        ))
    }

    /// 南瓜：瓜身 + 三条瓜棱 + 蒂 + 高光。第一版只有椭圆 + 锯齿嘴，太简陋。
    private static func pumpkin(at c: CGPoint, r: CGFloat, palette: Palette, in ctx: CGContext) {
        // 身
        palette.primary.setFill()
        let body = CGRect(x: c.x - r, y: c.y - r * 0.86, width: r * 2, height: r * 1.72)
        ctx.fillEllipse(in: body)

        // 瓜棱：三条略窄的暗色椭圆，压出体积。
        // 椭圆在瓜身边缘处会探出去（宽的地方矮、窄的地方高），画出来像多了一对耳朵，
        // 所以先裁到瓜身里再画，棱就永远长在瓜身上。
        ctx.saveGState()
        ctx.addEllipse(in: body)
        ctx.clip()
        palette.secondary.withAlphaComponent(0.40).setFill()
        for offset in [-0.40, 0.0, 0.40] {
            let w = r * 0.32
            ctx.fillEllipse(in: CGRect(
                x: c.x + offset * r * 2 - w / 2,
                y: c.y - r * 0.86,
                width: w,
                height: r * 1.72
            ))
        }
        ctx.restoreGState()

        // 蒂：带一点弧度的深色梗
        palette.deep.withAlphaComponent(0.9).setFill()
        let stem = CGMutablePath()
        stem.move(to: CGPoint(x: c.x - r * 0.13, y: c.y + r * 0.72))
        stem.addQuadCurve(
            to: CGPoint(x: c.x + r * 0.06, y: c.y + r * 1.18),
            control: CGPoint(x: c.x - r * 0.02, y: c.y + r * 0.98)
        )
        stem.addQuadCurve(
            to: CGPoint(x: c.x + r * 0.17, y: c.y + r * 0.70),
            control: CGPoint(x: c.x + r * 0.18, y: c.y + r * 0.96)
        )
        stem.closeSubpath()
        fill(stem, palette.deep.withAlphaComponent(0.9), in: ctx)

        // 眼睛：两个斜三角
        palette.deep.setFill()
        for sign: CGFloat in [-1, 1] {
            let eye = CGMutablePath()
            let ex = c.x + sign * r * 0.38
            eye.move(to: CGPoint(x: ex, y: c.y - r * 0.44))
            eye.addLine(to: CGPoint(x: ex - r * 0.20, y: c.y - r * 0.06))
            eye.addLine(to: CGPoint(x: ex + r * 0.20, y: c.y - r * 0.06))
            eye.closeSubpath()
            fill(eye, palette.deep, in: ctx)
        }

        // 嘴：上下起伏的锯齿
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: c.x - r * 0.58, y: c.y + r * 0.30))
        for i in 0...5 {
            let x = c.x - r * 0.58 + r * 1.16 * CGFloat(i) / 5
            let y = c.y + r * (i % 2 == 0 ? 0.30 : 0.54)
            mouth.addLine(to: CGPoint(x: x, y: y))
        }
        mouth.addLine(to: CGPoint(x: c.x + r * 0.58, y: c.y + r * 0.42))
        mouth.addLine(to: CGPoint(x: c.x - r * 0.58, y: c.y + r * 0.42))
        mouth.closeSubpath()
        fill(mouth, palette.deep, in: ctx)
    }

    /// 蝙蝠：身体 + 尖耳朵 + 两片带深凹口的翅膀。
    /// 第二版画成了"白色小鸟"：翅膀全是圆弧没有尖角，眼睛还是白底白点等于没画。
    /// 现在翅膀下缘改成三段波浪凹口、顶上补两只尖耳朵，眼睛用永远深色的墨。
    private static func bat(
        at c: CGPoint, r: CGFloat, color: UIColor, palette: Palette, in ctx: CGContext
    ) {
        // 翅膀：左右各画一次，镜像
        for sign: CGFloat in [-1, 1] {
            let p = CGMutablePath()
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: c.x + sign * x * r, y: c.y + y * r)
            }
            p.move(to: pt(0.04, -0.30))
            // 上缘：从身体甩到翼尖
            p.addQuadCurve(to: pt(0.60, -0.78), control: pt(0.28, -0.76))
            p.addQuadCurve(to: pt(1.00, -0.30), control: pt(0.94, -0.66))
            // 下缘：三段波浪往回收
            p.addQuadCurve(to: pt(0.80, 0.10), control: pt(0.92, -0.06))
            p.addQuadCurve(to: pt(0.62, -0.10), control: pt(0.70, -0.12))
            p.addQuadCurve(to: pt(0.46, 0.16), control: pt(0.54, 0.16))
            p.addQuadCurve(to: pt(0.30, -0.04), control: pt(0.38, -0.06))
            p.addQuadCurve(to: pt(0.08, 0.34), control: pt(0.16, 0.28))
            p.closeSubpath()
            fill(p, color, in: ctx)
        }

        // 身体
        color.setFill()
        ctx.fillEllipse(in: CGRect(
            x: c.x - r * 0.26, y: c.y - r * 0.34, width: r * 0.52, height: r * 0.72
        ))

        // 耳朵：两个尖三角
        for sign: CGFloat in [-1, 1] {
            let ear = CGMutablePath()
            ear.move(to: CGPoint(x: c.x + sign * r * 0.04, y: c.y - r * 0.26))
            ear.addLine(to: CGPoint(x: c.x + sign * r * 0.26, y: c.y - r * 0.68))
            ear.addLine(to: CGPoint(x: c.x + sign * r * 0.28, y: c.y - r * 0.18))
            ear.closeSubpath()
            fill(ear, color, in: ctx)
        }

        // 眼睛：必须是深色，白色蝙蝠上白点等于没画
        palette.deep.setFill()
        for sign: CGFloat in [-1, 1] {
            ctx.fillEllipse(in: CGRect(
                x: c.x + sign * r * 0.11 - r * 0.055,
                y: c.y - r * 0.16,
                width: r * 0.11,
                height: r * 0.13
            ))
        }
    }

    /// 幽灵：圆头顶 + 三段波浪下摆 + 两只眼睛。
    private static func ghost(
        at c: CGPoint, r: CGFloat, color: UIColor, palette: Palette, in ctx: CGContext
    ) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - r, y: c.y + r * 0.86))
        p.addLine(to: CGPoint(x: c.x - r, y: c.y - r * 0.18))
        p.addQuadCurve(
            to: CGPoint(x: c.x, y: c.y - r),
            control: CGPoint(x: c.x - r, y: c.y - r)
        )
        p.addQuadCurve(
            to: CGPoint(x: c.x + r, y: c.y - r * 0.18),
            control: CGPoint(x: c.x + r, y: c.y - r)
        )
        p.addLine(to: CGPoint(x: c.x + r, y: c.y + r * 0.86))
        // 波浪下摆：三个半圆
        for i in 0..<3 {
            let x0 = c.x + r - CGFloat(i) * (2 * r / 3)
            p.addQuadCurve(
                to: CGPoint(x: x0 - 2 * r / 3, y: c.y + r * 0.86),
                control: CGPoint(x: x0 - r / 3, y: c.y + r * (i % 2 == 0 ? 1.22 : 0.54))
            )
        }
        p.closeSubpath()
        fill(p, color, in: ctx)

        // 眼睛：深色椭圆 + 白点
        for sign: CGFloat in [-1, 1] {
            let eye = CGRect(
                x: c.x + sign * r * 0.34 - r * 0.13,
                y: c.y - r * 0.28,
                width: r * 0.26,
                height: r * 0.34
            )
            palette.deep.withAlphaComponent(0.85).setFill()
            ctx.fillEllipse(in: eye)
            UIColor.white.withAlphaComponent(0.8).setFill()
            ctx.fillEllipse(in: eye.insetBy(dx: r * 0.06, dy: r * 0.08).offsetBy(dx: 0, dy: r * 0.05))
        }
    }

    /// 角落蜘蛛网：5 条辐射线 + 3 圈折线。画在白卡四角之外。
    private static func web(
        at corner: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext, flip: Bool = false
    ) {
        guard r > 0 else { return }
        let signX: CGFloat = flip ? -1 : 1
        let signY: CGFloat = flip ? -1 : 1
        color.withAlphaComponent(0.5).setStroke()
        ctx.setLineWidth(max(1, r * 0.02))
        let angles = stride(from: 0.0, through: .pi / 2, by: .pi / 8)
        let rays = angles.map { angle -> CGPoint in
            CGPoint(
                x: corner.x + signX * cos(angle) * r,
                y: corner.y + signY * sin(angle) * r
            )
        }
        for p in rays {
            ctx.move(to: corner)
            ctx.addLine(to: p)
            ctx.strokePath()
        }
        for ring in 1...3 {
            let scale = CGFloat(ring) / 3
            let points = rays.map { p in
                CGPoint(
                    x: corner.x + (p.x - corner.x) * scale,
                    y: corner.y + (p.y - corner.y) * scale
                )
            }
            ctx.beginPath()
            ctx.move(to: points[0])
            for p in points.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        }
    }

    /// 雪花：六角对称 + 中心六边形 + 末端小分叉，白底上用深色描边保证可见。
    private static func snowflake(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(max(1.2, r * 0.14))
        color.setStroke()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let dx = cos(angle), dy = sin(angle)
            ctx.move(to: CGPoint(x: c.x - dx * r, y: c.y - dy * r))
            ctx.addLine(to: CGPoint(x: c.x + dx * r, y: c.y + dy * r))
            ctx.strokePath()
            for t: CGFloat in [0.58, 0.82] {
                let bx = c.x + dx * r * t, by = c.y + dy * r * t
                for side: CGFloat in [-1, 1] {
                    let a = angle + side * .pi / 3
                    ctx.move(to: CGPoint(x: bx, y: by))
                    ctx.addLine(to: CGPoint(
                        x: bx + cos(a) * r * 0.3,
                        y: by + sin(a) * r * 0.3
                    ))
                    ctx.strokePath()
                }
            }
        }
        // 中心六边形
        let hex = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let p = CGPoint(x: c.x + cos(angle) * r * 0.22, y: c.y + sin(angle) * r * 0.22)
            i == 0 ? hex.move(to: p) : hex.addLine(to: p)
        }
        hex.closeSubpath()
        fill(hex, color, in: ctx)
        ctx.restoreGState()
    }

    /// 松树：三层三角叠出来 + 树干，一眼就是"冬天"。
    private static func pineTree(at c: CGPoint, r: CGFloat, color: UIColor, in ctx: CGContext) {
        color.setFill()
        // 树干
        ctx.fill(CGRect(x: c.x - r * 0.10, y: c.y + r * 0.62, width: r * 0.20, height: r * 0.34))
        // 三层树冠，从下往上收
        let tiers: [(CGFloat, CGFloat)] = [(0.62, 1.00), (0.22, 0.82), (-0.18, 0.62)]
        for (offsetY, widthScale) in tiers {
            let w = r * widthScale
            let h = r * 0.78
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c.x, y: c.y + offsetY * r - h * 0.5))
            path.addLine(to: CGPoint(x: c.x + w, y: c.y + offsetY * r + h * 0.5))
            path.addLine(to: CGPoint(x: c.x - w, y: c.y + offsetY * r + h * 0.5))
            path.closeSubpath()
            fill(path, color, in: ctx)
        }
        // 顶部小尖
        let tip = CGMutablePath()
        tip.move(to: CGPoint(x: c.x, y: c.y - r * 0.92))
        tip.addLine(to: CGPoint(x: c.x + r * 0.24, y: c.y - r * 0.44))
        tip.addLine(to: CGPoint(x: c.x - r * 0.24, y: c.y - r * 0.44))
        tip.closeSubpath()
        fill(tip, color, in: ctx)
    }

    /// 礼物盒：盒身 + 盖子 + 竖丝带 + 蝴蝶结。
    private static func gift(
        at c: CGPoint, r: CGFloat, color: UIColor, palette: Palette, in ctx: CGContext
    ) {
        color.setFill()
        ctx.fill(CGRect(x: c.x - r, y: c.y - r * 0.70, width: r * 2, height: r * 1.6))
        // 盖子略宽一点
        ctx.fill(CGRect(x: c.x - r * 1.12, y: c.y - r * 0.94, width: r * 2.24, height: r * 0.34))
        // 竖丝带
        palette.light.withAlphaComponent(0.92).setFill()
        ctx.fill(CGRect(x: c.x - r * 0.17, y: c.y - r * 0.94, width: r * 0.34, height: r * 1.84))
        // 蝴蝶结
        palette.secondary.setFill()
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.66, y: c.y - r * 1.24, width: r * 0.58, height: r * 0.42))
        ctx.fillEllipse(in: CGRect(x: c.x + r * 0.08, y: c.y - r * 1.24, width: r * 0.58, height: r * 0.42))
    }

    /// 气球：椭圆球体 + 结 + 弧线绳 + 高光。
    private static func balloon(
        at c: CGPoint, r: CGFloat, color: UIColor, palette: Palette, in ctx: CGContext
    ) {
        color.setFill()
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.74, y: c.y - r, width: r * 1.48, height: r * 1.72))
        let knot = CGMutablePath()
        knot.move(to: CGPoint(x: c.x - r * 0.15, y: c.y + r * 0.68))
        knot.addLine(to: CGPoint(x: c.x + r * 0.15, y: c.y + r * 0.68))
        knot.addLine(to: CGPoint(x: c.x, y: c.y + r * 0.95))
        knot.closeSubpath()
        fill(knot, color, in: ctx)

        palette.ink.withAlphaComponent(0.35).setStroke()
        ctx.setLineWidth(max(1, r * 0.04))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: c.x, y: c.y + r * 0.95))
        ctx.addQuadCurve(
            to: CGPoint(x: c.x + r * 0.20, y: c.y + r * 1.85),
            control: CGPoint(x: c.x - r * 0.26, y: c.y + r * 1.42)
        )
        ctx.strokePath()

        UIColor.white.withAlphaComponent(0.5).setFill()
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.44, y: c.y - r * 0.72, width: r * 0.3, height: r * 0.52))
    }

    /// 上边缘的三角彩旗串。
    private static func bunting(in canvas: CGRect, palette: Palette, ctx: CGContext) {
        palette.secondary.withAlphaComponent(0.65).setStroke()
        ctx.setLineWidth(max(1, canvas.width * 0.004))
        ctx.beginPath()
        ctx.move(to: point(0, 0.035, in: canvas))
        ctx.addQuadCurve(
            to: point(1, 0.035, in: canvas),
            control: point(0.5, 0.115, in: canvas)
        )
        ctx.strokePath()

        for i in 0..<7 {
            let x = 0.08 + CGFloat(i) * 0.14
            let t = (x - 0.5) / 0.5
            let y = 0.035 + 0.08 * (1 - t * t)
            let c = point(x, y, in: canvas)
            let r = radius(0.038, in: canvas)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x - r, y: c.y))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y))
            p.addLine(to: CGPoint(x: c.x, y: c.y + r * 1.9))
            p.closeSubpath()
            fill(p, i % 2 == 0 ? palette.primary : palette.secondary, in: ctx)
        }
    }

    // MARK: - 漫画气泡边框与波普图元 (Comic Speech Bubble & Pop Art)

    private static func comicBubble(
        in canvas: CGRect,
        side: CGFloat,
        cardRect: CGRect,
        palette: Palette,
        in ctx: CGContext
    ) {
        let ink = UIColor(hex: 0x18181B)
        let yellow = UIColor(hex: 0xFACC15)
        let red = UIColor(hex: 0xEF4444)

        // 1. 速度线 (Speed Lines)
        ink.setStroke()
        ctx.setLineWidth(max(1.5, side * 0.008))
        // 左边缘垂直速度线
        ctx.strokeLineSegments(between: [
            CGPoint(x: canvas.minX + canvas.width * 0.068, y: canvas.minY + canvas.height * 0.54),
            CGPoint(x: canvas.minX + canvas.width * 0.068, y: canvas.minY + canvas.height * 0.68),
            CGPoint(x: canvas.minX + canvas.width * 0.078, y: canvas.minY + canvas.height * 0.56),
            CGPoint(x: canvas.minX + canvas.width * 0.078, y: canvas.minY + canvas.height * 0.64)
        ])
        // 右边缘速度线
        ctx.strokeLineSegments(between: [
            CGPoint(x: canvas.maxX - canvas.width * 0.078, y: canvas.minY + canvas.height * 0.25),
            CGPoint(x: canvas.maxX - canvas.width * 0.078, y: canvas.minY + canvas.height * 0.38)
        ])
        // 下边缘水平速度线
        ctx.strokeLineSegments(between: [
            CGPoint(x: canvas.minX + canvas.width * 0.24, y: canvas.maxY - canvas.height * 0.165),
            CGPoint(x: canvas.minX + canvas.width * 0.40, y: canvas.maxY - canvas.height * 0.165),
            CGPoint(x: canvas.minX + canvas.width * 0.28, y: canvas.maxY - canvas.height * 0.155),
            CGPoint(x: canvas.minX + canvas.width * 0.36, y: canvas.maxY - canvas.height * 0.155)
        ])

        // 2. 右上角：动感射线 + 五角星
        drawComicRays(
            center: CGPoint(x: canvas.maxX - canvas.width * 0.11, y: canvas.minY + canvas.height * 0.13),
            length: side * 0.16,
            angles: [-0.35, -0.68, -1.02],
            yellow: yellow,
            red: red,
            ink: ink,
            in: ctx
        )
        comicStar(
            at: CGPoint(x: canvas.maxX - canvas.width * 0.06, y: canvas.minY + canvas.height * 0.23),
            r: side * 0.038,
            fill: yellow,
            stroke: ink,
            lineWidth: max(1.5, side * 0.007),
            in: ctx
        )
        comicStar(
            at: CGPoint(x: canvas.maxX - canvas.width * 0.19, y: canvas.minY + canvas.height * 0.11),
            r: side * 0.046,
            fill: UIColor.white,
            stroke: ink,
            lineWidth: max(1.5, side * 0.007),
            in: ctx
        )

        // 3. 左下角：爆炸星 + 动感射线 + 五角星
        comicBurstStar(
            at: CGPoint(x: canvas.minX + canvas.width * 0.055, y: canvas.maxY - canvas.height * 0.28),
            outerR: side * 0.062,
            innerR: side * 0.032,
            points: 8,
            fill: red,
            stroke: ink,
            lineWidth: max(1.5, side * 0.007),
            in: ctx
        )
        drawComicRays(
            center: CGPoint(x: canvas.minX + canvas.width * 0.08, y: canvas.maxY - canvas.height * 0.18),
            length: side * 0.16,
            angles: [2.35, 2.70, 3.05],
            yellow: yellow,
            red: red,
            ink: ink,
            in: ctx
        )
        comicStar(
            at: CGPoint(x: canvas.minX + canvas.width * 0.18, y: canvas.maxY - canvas.height * 0.14),
            r: side * 0.038,
            fill: yellow,
            stroke: ink,
            lineWidth: max(1.5, side * 0.007),
            in: ctx
        )

        // 4. 黄色气泡轮廓与右下尖角尾巴 (Speech Bubble Frame)
        let bubbleRect = cardRect.insetBy(dx: -side * 0.068, dy: -side * 0.068)
        let bubblePath = CGMutablePath()
        let r = side * 0.11
        let minX = bubbleRect.minX
        let maxX = bubbleRect.maxX
        let minY = bubbleRect.minY
        let maxY = bubbleRect.maxY

        bubblePath.move(to: CGPoint(x: minX + r, y: minY))
        bubblePath.addLine(to: CGPoint(x: maxX - r, y: minY))
        bubblePath.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX, y: minY + r), radius: r)
        bubblePath.addLine(to: CGPoint(x: maxX, y: maxY - side * 0.14))

        // 右下气泡尖角
        let tailTip = CGPoint(x: maxX + side * 0.05, y: maxY + side * 0.13)
        bubblePath.addCurve(
            to: tailTip,
            control1: CGPoint(x: maxX + side * 0.01, y: maxY + side * 0.01),
            control2: CGPoint(x: maxX + side * 0.03, y: maxY + side * 0.08)
        )
        bubblePath.addCurve(
            to: CGPoint(x: maxX - side * 0.22, y: maxY),
            control1: CGPoint(x: maxX - side * 0.05, y: maxY + side * 0.11),
            control2: CGPoint(x: maxX - side * 0.14, y: maxY + side * 0.02)
        )

        bubblePath.addLine(to: CGPoint(x: minX + r, y: maxY))
        bubblePath.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX, y: maxY - r), radius: r)
        bubblePath.addLine(to: CGPoint(x: minX, y: minY + r))
        bubblePath.addArc(tangent1End: CGPoint(x: minX, y: minY), tangent2End: CGPoint(x: minX + r, y: minY), radius: r)
        bubblePath.closeSubpath()

        // 填充黄色主体
        yellow.setFill()
        ctx.addPath(bubblePath)
        ctx.fillPath()

        // 黑色漫画外描边
        ink.setStroke()
        ctx.setLineWidth(max(2.5, side * 0.020))
        ctx.addPath(bubblePath)
        ctx.strokePath()

        // 内部白色高光圈
        let highlightRect = bubbleRect.insetBy(dx: side * 0.025, dy: side * 0.025)
        let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: r * 0.78).cgPath
        UIColor.white.withAlphaComponent(0.85).setStroke()
        ctx.setLineWidth(max(1.5, side * 0.010))
        ctx.addPath(highlightPath)
        ctx.strokePath()
    }

    private static func drawComicRays(
        center: CGPoint,
        length: CGFloat,
        angles: [CGFloat],
        yellow: UIColor,
        red: UIColor,
        ink: UIColor,
        in ctx: CGContext
    ) {
        let widthHalf: CGFloat = length * 0.14
        for (idx, angle) in angles.enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: angle)

            let p = CGMutablePath()
            p.move(to: CGPoint(x: -widthHalf, y: 0))
            p.addLine(to: CGPoint(x: widthHalf, y: 0))
            p.addLine(to: CGPoint(x: widthHalf * 0.7, y: length))
            p.addLine(to: CGPoint(x: -widthHalf * 0.7, y: length))
            p.closeSubpath()

            let fillCol = idx % 2 == 0 ? red : (idx == 1 ? yellow : UIColor.white)
            fillCol.setFill()
            ctx.addPath(p)
            ctx.fillPath()

            ink.setStroke()
            ctx.setLineWidth(max(1.5, length * 0.045))
            ctx.addPath(p)
            ctx.strokePath()

            ctx.restoreGState()
        }
    }

    private static func comicStar(
        at c: CGPoint,
        r: CGFloat,
        fill: UIColor,
        stroke: UIColor,
        lineWidth: CGFloat,
        in ctx: CGContext
    ) {
        let path = CGMutablePath()
        for i in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rad = i % 2 == 0 ? r : r * 0.46
            let p = CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()

        fill.setFill()
        ctx.addPath(path)
        ctx.fillPath()

        stroke.setStroke()
        ctx.setLineWidth(lineWidth)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func comicBurstStar(
        at c: CGPoint,
        outerR: CGFloat,
        innerR: CGFloat,
        points: Int,
        fill: UIColor,
        stroke: UIColor,
        lineWidth: CGFloat,
        in ctx: CGContext
    ) {
        let path = CGMutablePath()
        let count = points * 2
        for i in 0..<count {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let rad = i % 2 == 0 ? outerR : innerR
            let p = CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()

        fill.setFill()
        ctx.addPath(path)
        ctx.fillPath()

        stroke.setStroke()
        ctx.setLineWidth(lineWidth)
        ctx.addPath(path)
        ctx.strokePath()
    }
}
