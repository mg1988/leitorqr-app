import AppKit
import CoreGraphics
import Foundation

// OBSOLETE-2026-11-27：这个脚本画的是旧图标（纯白陶瓷）。现在的图标是「墨黑三眼 + 薄荷绿点」，
// PNG 直接放在 Assets.xcassets 里。为防止误跑覆盖新图标，这里直接退出。
FileHandle.standardError.write("gen script obsolete since 2026-11-27, new art lives in Assets.xcassets\n".data(using: .utf8)!)
exit(1)

/// Leitor QR App Icon Generator (Core Graphics, 1024×1024, sRGB, no alpha channel).
///
/// Final Design:「方案 B · 纯白陶瓷 (Ceramic Studio White)」
///   · Universal / Light: Crisp Studio Ceramic White base (#FFFFFF -> #EEF2F8) with Royal Sapphire Blue QR glyph
///   · Dark Appearance: Obsidian Space Black (#121622 -> #04060C) with glowing sapphire & pure white glass glyph
///
/// Usage:
///   swift scripts/gen_app_icon.swift [output_dir]
///

let size: CGFloat = 1024
let mid = size / 2

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext() -> CGContext? {
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func renderIcon(isDark: Bool) -> CGImage? {
    guard let ctx = makeContext() else { return nil }

    let span: CGFloat = 600
    let arm: CGFloat = 175
    let w: CGFloat = 58
    let outerR: CGFloat = 50
    let innerR: CGFloat = 14
    let endR: CGFloat = 8

    let x0 = mid - span / 2
    let y0 = mid - span / 2

    if !isDark {
        // -------------------------------------------------------------
        // Universal / Light: Pure Studio Ceramic White + Sapphire Blue
        // -------------------------------------------------------------
        let bgColors = [rgb(255, 255, 255), rgb(238, 242, 248)] as CFArray
        let bgGrad = CGGradient(colorsSpace: space, colors: bgColors, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])

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
            ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 24, color: rgb(0, 40, 120, 0.22))
            let blueColors = [rgb(10, 120, 255), rgb(0, 90, 235)] as CFArray
            let blueGrad = CGGradient(colorsSpace: space, colors: blueColors, locations: [0.0, 1.0])!
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(blueGrad, start: CGPoint(x: x0, y: y0), end: CGPoint(x: x0 + arm, y: y0 + arm), options: [])
            ctx.restoreGState()

            // Specular top highlight
            ctx.saveGState()
            ctx.setLineWidth(1.5)
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
        let coreSize: CGFloat = 210
        let coreRect = CGRect(x: mid - coreSize / 2, y: mid - coreSize / 2, width: coreSize, height: coreSize)
        let corePath = CGPath(roundedRect: coreRect, cornerWidth: 46, cornerHeight: 46, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 24, color: rgb(0, 40, 120, 0.22))
        ctx.setLineWidth(36)
        let coreColors = [rgb(10, 120, 255), rgb(0, 90, 235)] as CFArray
        let coreGrad = CGGradient(colorsSpace: space, colors: coreColors, locations: [0.0, 1.0])!
        ctx.addPath(corePath)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(coreGrad, start: CGPoint(x: coreRect.minX, y: coreRect.minY), end: CGPoint(x: coreRect.maxX, y: coreRect.maxY), options: [])
        ctx.restoreGState()

        let dotSize: CGFloat = 68
        let dotRect = CGRect(x: mid - dotSize / 2, y: mid - dotSize / 2, width: dotSize, height: dotSize)
        let dotPath = CGPath(roundedRect: dotRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 16, color: rgb(0, 40, 120, 0.18))
        ctx.addPath(dotPath)
        ctx.clip()
        ctx.drawLinearGradient(coreGrad, start: CGPoint(x: dotRect.minX, y: dotRect.minY), end: CGPoint(x: dotRect.maxX, y: dotRect.maxY), options: [])
        ctx.restoreGState()

    } else {
        // -------------------------------------------------------------
        // Dark Appearance: Obsidian Space Black + Glowing Sapphire
        // -------------------------------------------------------------
        let bgColors = [rgb(18, 24, 38), rgb(4, 7, 14)] as CFArray
        let bgGrad = CGGradient(colorsSpace: space, colors: bgColors, locations: [0.0, 1.0])!
        ctx.drawRadialGradient(bgGrad, startCenter: CGPoint(x: mid, y: mid - 60), startRadius: 40, endCenter: CGPoint(x: mid, y: mid), endRadius: 720, options: [.drawsAfterEndLocation])

        func drawOneCornerDark() {
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
            ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 28, color: rgb(0, 0, 0, 0.6))
            ctx.setFillColor(rgb(255, 255, 255, 0.96))
            ctx.addPath(path)
            ctx.fillPath()

            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setLineWidth(1.8)
            ctx.setStrokeColor(rgb(255, 255, 255, 0.45))
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        }

        for i in 0..<4 {
            ctx.saveGState()
            ctx.translateBy(x: mid, y: mid)
            ctx.rotate(by: CGFloat(i) * .pi / 2.0)
            ctx.translateBy(x: -mid, y: -mid)
            drawOneCornerDark()
            ctx.restoreGState()
        }

        // Center Sapphire Core in Dark Mode
        let coreSize: CGFloat = 210
        let coreRect = CGRect(x: mid - coreSize / 2, y: mid - coreSize / 2, width: coreSize, height: coreSize)
        let corePath = CGPath(roundedRect: coreRect, cornerWidth: 46, cornerHeight: 46, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 32, color: rgb(0, 122, 255, 0.65))
        let blueColors = [rgb(44, 156, 255), rgb(0, 96, 246)] as CFArray
        let blueGrad = CGGradient(colorsSpace: space, colors: blueColors, locations: [0.0, 1.0])!
        ctx.addPath(corePath)
        ctx.clip()
        ctx.drawLinearGradient(blueGrad, start: CGPoint(x: coreRect.minX, y: coreRect.minY), end: CGPoint(x: coreRect.maxX, y: coreRect.maxY), options: [])
        ctx.restoreGState()

        // Inner White QR Frame in Dark Mode
        let innerRingSize: CGFloat = 120
        let innerRingRect = CGRect(x: mid - innerRingSize / 2, y: mid - innerRingSize / 2, width: innerRingSize, height: innerRingSize)
        let innerRingPath = CGPath(roundedRect: innerRingRect, cornerWidth: 26, cornerHeight: 26, transform: nil)
        ctx.saveGState()
        ctx.setLineWidth(18)
        ctx.setStrokeColor(rgb(255, 255, 255, 0.96))
        ctx.addPath(innerRingPath)
        ctx.strokePath()
        ctx.restoreGState()

        let dotSize: CGFloat = 46
        let dotRect = CGRect(x: mid - dotSize / 2, y: mid - dotSize / 2, width: dotSize, height: dotSize)
        let dotPath = CGPath(roundedRect: dotRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.setFillColor(rgb(255, 255, 255, 0.96))
        ctx.addPath(dotPath)
        ctx.fillPath()
    }

    return ctx.makeImage()
}

let args = Array(CommandLine.arguments.dropFirst())
let pathArg = args.first(where: { !$0.starts(with: "--") })
let output = URL(fileURLWithPath: pathArg ?? "LeitorQR/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func writePNG(_ img: CGImage, filename: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(filename)")
        exit(1)
    }
    let url = output.appendingPathComponent(filename)
    do {
        try png.write(to: url)
        print("Wrote \(filename) (\(png.count) bytes)")
    } catch {
        print("Failed to write \(filename): \(error)")
        exit(1)
    }
}

guard let lightImg = renderIcon(isDark: false),
      let darkImg = renderIcon(isDark: true) else {
    print("Rendering failed")
    exit(1)
}

writePNG(lightImg, filename: "icon-1024.png")
writePNG(darkImg, filename: "icon-1024-dark.png")
print("Successfully generated LeitorQR App Icon (Option B · Ceramic Studio White)")
