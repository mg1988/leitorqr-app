import AppKit
import CoreGraphics
import Foundation

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let artifactDir = "/Users/genweimi/.gemini/antigravity/brain/a4bafc0a-0b9b-4457-9024-d582bab055b6"
guard let lightIcon = NSImage(contentsOfFile: "\(artifactDir)/app_icon_1024_light.png")?.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let darkIcon = NSImage(contentsOfFile: "\(artifactDir)/app_icon_1024_dark.png")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Could not load master icons")
    exit(1)
}

let canvasW: CGFloat = 1440
let canvasH: CGFloat = 900

let ctx = CGContext(
    data: nil,
    width: Int(canvasW),
    height: Int(canvasH),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Use standard top-left origin (y downwards)
ctx.translateBy(x: 0, y: canvasH)
ctx.scaleBy(x: 1, y: -1)

// Fill dark studio background
ctx.setFillColor(rgb(10, 13, 20))
ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))

func drawText(_ str: String, font: NSFont, color: NSColor, x: CGFloat, y: CGFloat, alignCenter: Bool = false) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let attrStr = NSAttributedString(string: str, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, [])

    ctx.saveGState()
    // Invert for text draw in top-left origin coordinate space
    ctx.textMatrix = .identity
    let drawX = alignCenter ? (x - bounds.width / 2) : x
    ctx.translateBy(x: drawX, y: y + bounds.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, icon: CGImage, title: String, subtitle: String, isDark: Bool) {
    let cardRect = CGRect(x: x, y: y, width: w, height: h)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 36, color: rgb(0, 0, 0, 0.45))
    ctx.setFillColor(rgb(18, 22, 32))
    ctx.addPath(cardPath)
    ctx.fillPath()

    // Border
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setLineWidth(1.5)
    ctx.setStrokeColor(rgb(255, 255, 255, 0.08))
    ctx.addPath(cardPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Header
    drawText(title, font: .systemFont(ofSize: 22, weight: .bold), color: .white, x: x + 36, y: y + 36)
    drawText(subtitle, font: .systemFont(ofSize: 13, weight: .regular), color: NSColor(white: 0.65, alpha: 1), x: x + 36, y: y + 68)

    // Master App Icon (300x300)
    let iconSize: CGFloat = 300
    let iconX = x + (w - iconSize) / 2
    let iconY = y + 115
    let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

    let cr = iconSize * 0.2237
    let iconPath = CGPath(roundedRect: iconRect, cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 32, color: rgb(0, 0, 0, 0.5))
    ctx.addPath(iconPath)
    ctx.clip()
    // Need to draw upright in flipped coordinates
    ctx.saveGState()
    ctx.translateBy(x: 0, y: iconRect.origin.y * 2 + iconRect.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(icon, in: iconRect)
    ctx.restoreGState()
    ctx.restoreGState()

    // Specular border
    ctx.saveGState()
    ctx.setLineWidth(1.5)
    ctx.setStrokeColor(rgb(255, 255, 255, 0.18))
    ctx.addPath(iconPath)
    ctx.strokePath()
    ctx.restoreGState()

    // App Label
    drawText("Leitor QR", font: .systemFont(ofSize: 18, weight: .semibold), color: .white, x: iconRect.midX, y: iconRect.maxY + 20, alignCenter: true)

    // Dock Preview (60x60pt home screen dock)
    let dockW = w - 60
    let dockH: CGFloat = 96
    let dockX = x + 30
    let dockY = y + h - dockH - 36
    let dockRect = CGRect(x: dockX, y: dockY, width: dockW, height: dockH)
    let dockPath = CGPath(roundedRect: dockRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

    ctx.saveGState()
    ctx.setFillColor(rgb(255, 255, 255, isDark ? 0.08 : 0.12))
    ctx.addPath(dockPath)
    ctx.fillPath()
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(rgb(255, 255, 255, 0.12))
    ctx.addPath(dockPath)
    ctx.strokePath()
    ctx.restoreGState()

    let dockIconSize: CGFloat = 60
    let dockCr = dockIconSize * 0.2237
    let slotSpacing = (dockW - 4 * dockIconSize) / 5

    // Slot 1: Safari
    let s1Rect = CGRect(x: dockX + slotSpacing, y: dockY + (dockH - dockIconSize) / 2, width: dockIconSize, height: dockIconSize)
    let s1Path = CGPath(roundedRect: s1Rect, cornerWidth: dockCr, cornerHeight: dockCr, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(rgb(30, 140, 255))
    ctx.addPath(s1Path)
    ctx.fillPath()
    ctx.restoreGState()

    // Slot 2: Leitor QR (Our Hero!)
    let s2Rect = CGRect(x: dockX + slotSpacing * 2 + dockIconSize, y: dockY + (dockH - dockIconSize) / 2, width: dockIconSize, height: dockIconSize)
    let s2Path = CGPath(roundedRect: s2Rect, cornerWidth: dockCr, cornerHeight: dockCr, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 10, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(s2Path)
    ctx.clip()
    ctx.saveGState()
    ctx.translateBy(x: 0, y: s2Rect.origin.y * 2 + s2Rect.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(icon, in: s2Rect)
    ctx.restoreGState()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(rgb(255, 255, 255, 0.2))
    ctx.addPath(s2Path)
    ctx.strokePath()
    ctx.restoreGState()

    // Slot 3: Photos
    let s3Rect = CGRect(x: dockX + slotSpacing * 3 + dockIconSize * 2, y: dockY + (dockH - dockIconSize) / 2, width: dockIconSize, height: dockIconSize)
    let s3Path = CGPath(roundedRect: s3Rect, cornerWidth: dockCr, cornerHeight: dockCr, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(rgb(255, 255, 255))
    ctx.addPath(s3Path)
    ctx.fillPath()
    ctx.restoreGState()

    // Slot 4: Settings
    let s4Rect = CGRect(x: dockX + slotSpacing * 4 + dockIconSize * 3, y: dockY + (dockH - dockIconSize) / 2, width: dockIconSize, height: dockIconSize)
    let s4Path = CGPath(roundedRect: s4Rect, cornerWidth: dockCr, cornerHeight: dockCr, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(rgb(140, 142, 150))
    ctx.addPath(s4Path)
    ctx.fillPath()
    ctx.restoreGState()
}

let cardW: CGFloat = 630
let cardH: CGFloat = 780
let cardY: CGFloat = 60

drawCard(
    x: 60,
    y: cardY,
    w: cardW,
    h: cardH,
    icon: lightIcon,
    title: "日间/标准外观 (Universal / Light)",
    subtitle: "纯净陶瓷冷白底座 + 皇家深蓝宝石取景符 + 微距触觉阴影",
    isDark: false
)

drawCard(
    x: 750,
    y: cardY,
    w: cardW,
    h: cardH,
    icon: darkIcon,
    title: "深色外观 (Dark Appearance)",
    subtitle: "深空黑曜石沉浸底座 + 纯白连续曲率取景框 + 蓝宝石高光核心",
    isDark: true
)

guard let outImage = ctx.makeImage() else {
    print("Failed to make final image")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: outImage)
let png = rep.representation(using: .png, properties: [:])!
let outPath = "\(artifactDir)/app_icon_showcase.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("Saved showcase to \(outPath)")
