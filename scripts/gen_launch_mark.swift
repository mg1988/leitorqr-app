import AppKit
import CoreGraphics
import Foundation

/// Native LaunchScreen brand mark (transparent background).
/// Synchronized with App Icon「方案 B · 纯白陶瓷 (Ceramic Studio White)」.
///
/// Logical size: 200pt (outputs @1x, @2x, @3x).
///

let logicalSide: CGFloat = 200
let scales: [CGFloat] = [1, 2, 3]

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ side: CGFloat) -> CGContext? {
    guard let ctx = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.translateBy(x: 0, y: side)
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func drawMark(ctx: CGContext, side: CGFloat) {
    let scale = side / 1024.0
    let mid = side / 2.0

    let span: CGFloat = 600 * scale
    let arm: CGFloat = 175 * scale
    let w: CGFloat = 58 * scale
    let outerR: CGFloat = 50 * scale
    let innerR: CGFloat = 14 * scale
    let endR: CGFloat = 8 * scale

    let x0 = mid - span / 2
    let y0 = mid - span / 2

    func drawOneCorner() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0 + arm - endR, y: y0))
        path.addLine(to: CGPoint(x: x0 + outerR, y: y0))
        path.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x0, y: y0 + outerR), radius: outerR)
        path.addLine(to: CGPoint(x: x0, y: y0 + arm - endR))
        path.addArc(tangent1End: CGPoint(x: x0, y: y0 + arm), tangent2End: CGPoint(x: x0 + endR, y: y0 + arm), radius: endR)
        path.addLine(to: CGPoint(x: x0 + w - endR, y: y0 + arm))
        path.addArc(tangent1End: CGPoint(x: x0 + w, y: y0 + arm), tangent2End: CGPoint(x: x0 + w, y: y0 + arm - endR), radius: endR)
        path.addLine(to: CGPoint(x: x0 + w, y: y0 + w + innerR))
        path.addArc(tangent1End: CGPoint(x: x0 + w, y: y0 + w), tangent2End: CGPoint(x: x0 + w + innerR, y: y0 + w), radius: innerR)
        path.addLine(to: CGPoint(x: x0 + arm - endR, y: y0 + w))
        path.addArc(tangent1End: CGPoint(x: x0 + arm, y: y0 + w), tangent2End: CGPoint(x: x0 + arm, y: y0 + w - endR), radius: endR)
        path.addLine(to: CGPoint(x: x0 + arm, y: y0 + endR))
        path.addArc(tangent1End: CGPoint(x: x0 + arm, y: y0), tangent2End: CGPoint(x: x0 + arm - endR, y: y0), radius: endR)
        path.closeSubpath()

        ctx.saveGState()
        let blueColors = [rgb(10, 120, 255), rgb(0, 90, 235)] as CFArray
        let blueGrad = CGGradient(colorsSpace: space, colors: blueColors, locations: [0.0, 1.0])!
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(blueGrad, start: CGPoint(x: x0, y: y0), end: CGPoint(x: x0 + arm, y: y0 + arm), options: [])
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setLineWidth(1.5 * scale)
        ctx.setStrokeColor(rgb(255, 255, 255, 0.4))
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    for i in 0..<4 {
        ctx.saveGState()
        ctx.translateBy(x: mid, y: mid)
        ctx.rotate(by: CGFloat(i) * .pi / 2.0)
        ctx.translateBy(x: -mid, y: -mid)
        drawOneCorner()
        ctx.restoreGState()
    }

    // Center Sapphire QR Core
    let coreSize: CGFloat = 210 * scale
    let coreRect = CGRect(x: mid - coreSize / 2, y: mid - coreSize / 2, width: coreSize, height: coreSize)
    let corePath = CGPath(roundedRect: coreRect, cornerWidth: 46 * scale, cornerHeight: 46 * scale, transform: nil)

    ctx.saveGState()
    ctx.setLineWidth(36 * scale)
    let coreColors = [rgb(10, 120, 255), rgb(0, 90, 235)] as CFArray
    let coreGrad = CGGradient(colorsSpace: space, colors: coreColors, locations: [0.0, 1.0])!
    ctx.addPath(corePath)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(coreGrad, start: CGPoint(x: coreRect.minX, y: coreRect.minY), end: CGPoint(x: coreRect.maxX, y: coreRect.maxY), options: [])
    ctx.restoreGState()

    let dotSize: CGFloat = 68 * scale
    let dotRect = CGRect(x: mid - dotSize / 2, y: mid - dotSize / 2, width: dotSize, height: dotSize)
    let dotPath = CGPath(roundedRect: dotRect, cornerWidth: 16 * scale, cornerHeight: 16 * scale, transform: nil)
    ctx.saveGState()
    ctx.addPath(dotPath)
    ctx.clip()
    ctx.drawLinearGradient(coreGrad, start: CGPoint(x: dotRect.minX, y: dotRect.minY), end: CGPoint(x: dotRect.maxX, y: dotRect.maxY), options: [])
    ctx.restoreGState()
}

let args = Array(CommandLine.arguments.dropFirst())
let output = URL(fileURLWithPath: args.first ?? "LeitorQR/Resources/Assets.xcassets/LaunchMark.imageset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

// Clean out legacy mark.png without @1x
try? FileManager.default.removeItem(at: output.appendingPathComponent("mark.png"))

for scale in scales {
    let side = logicalSide * scale
    guard let ctx = makeContext(side) else { continue }
    drawMark(ctx: ctx, side: side)
    guard let image = ctx.makeImage() else { continue }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else { continue }

    let filename = "mark@\(Int(scale))x.png"
    let url = output.appendingPathComponent(filename)
    try? png.write(to: url)
    print("Wrote \(filename) (\(Int(side))x\(Int(side)))")
}
print("Successfully generated LaunchMark for Option B")
