import Foundation
import Vision
import CoreImage
import AppKit

// 用 Vision 的前景分割把素材从背景里抠出来，输出带 alpha 的 PNG。
// 这类 3D 渲染图边缘有半透明反光，硬阈值抠图会留下白边，系统分割更干净。
//
// 用法：swift scripts/cutout_foreground.swift <输入> <输出> [边长]

guard CommandLine.arguments.count >= 3 else {
    print("usage: cutout_foreground.swift <input> <output> [size]")
    exit(1)
}

let inURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])
let maxSize = CommandLine.arguments.count > 3 ? (Int(CommandLine.arguments[3]) ?? 512) : 512

let handler = VNImageRequestHandler(url: inURL, options: [:])
let request = VNGenerateForegroundInstanceMaskRequest()

do {
    try handler.perform([request])
} catch {
    print("ERROR: perform failed: \(error)")
    exit(1)
}

guard let observation = request.results?.first else {
    print("ERROR: no foreground instance found")
    exit(1)
}

let pixelBuffer: CVPixelBuffer
do {
    pixelBuffer = try observation.generateMaskedImage(
        ofInstances: observation.allInstances,
        from: handler,
        croppedToInstancesExtent: true
    )
} catch {
    print("ERROR: generateMaskedImage failed: \(error)")
    exit(1)
}

let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
let context = CIContext()
guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
    print("ERROR: createCGImage failed")
    exit(1)
}

// 等比缩放到目标边长，保持 alpha 不被预乘破坏。
let srcW = CGFloat(cgImage.width)
let srcH = CGFloat(cgImage.height)
let scale = CGFloat(maxSize) / max(srcW, srcH)
let dstW = max(1, Int((srcW * scale).rounded()))
let dstH = max(1, Int((srcH * scale).rounded()))

guard let ctx = CGContext(
    data: nil, width: dstW, height: dstH,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("ERROR: CGContext failed")
    exit(1)
}
ctx.interpolationQuality = .high
ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))

guard let scaled = ctx.makeImage() else {
    print("ERROR: makeImage failed")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: scaled)
guard let data = rep.representation(using: .png, properties: [:]) else {
    print("ERROR: png encode failed")
    exit(1)
}
try data.write(to: outURL)

print("OK \(cgImage.width)x\(cgImage.height) -> \(dstW)x\(dstH)")
