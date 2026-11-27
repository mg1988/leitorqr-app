#!/usr/bin/env swift
// 生成「一图看全」的验收码表：12 种内容类型 + 7 种码制 + 边界负载。
//
//   swift scripts/gen_test_qr_sheet.swift [输出路径]
//
// 默认输出 .build/shots/qr-test-sheet.png。
// 生成后用 `swift scripts/decode_barcode.swift <输出路径>` 做机器解码验收：
// 视觉上「像二维码」不算数，必须 Vision 解得出、内容对得上。
//
// 关键约束：所有码按**整数倍**模块放大后 1:1 贴到画布上，不做任何插值缩放——
// 非整数倍缩放会让短码（EAN-8）在整图里检不出。

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

// MARK: - 数据结构

enum Kind: String {
    case qr, aztec, pdf417, code128, ean13, ean8, code39
}

struct Sample {
    let title: String      // 画布上的短标签
    let payload: String    // 实际编码内容
    let kind: Kind
    let note: String       // 标签下的一行说明
}

let samples: [Sample] = [
    // ── 12 种内容类型（全部走 QR）──
    Sample(title: "01 网址 URL", payload: "https://exemplo.pt/loja?utm_source=qr", kind: .qr,
           note: "外部浏览器打开"),
    Sample(title: "02 纯文本 Text", payload: "Olá! Esta é uma mensagem de teste.", kind: .qr,
           note: "无结构化前缀 → text"),
    Sample(title: "03 Wi-Fi", payload: "WIFI:T:WPA;S:Casa-do-Joao;P:senha12345;;", kind: .qr,
           note: "SSID / 密码 / 加密方式"),
    Sample(title: "04 邮件 mailto", payload: "mailto:joao@exemplo.pt?subject=Ol%C3%A1&body=Teste", kind: .qr,
           note: "mailto: 结构化邮件"),
    Sample(title: "05 邮件 MATMSG", payload: "MATMSG:TO:joao@exemplo.pt;SUB:Olá;BODY:Teste;;", kind: .qr,
           note: "老式邮件码，同样归 email"),
    Sample(title: "06 电话 tel", payload: "tel:+351912345678", kind: .qr,
           note: "拨号"),
    Sample(title: "07 短信 SMS", payload: "SMSTO:912345678:Olá, cheguei!", kind: .qr,
           note: "预填收件人与正文"),
    Sample(title: "08 联系人 vCard", payload: "BEGIN:VCARD\nVERSION:3.0\nN:Silva;João;;;\nFN:João Silva\nTEL;TYPE=CELL:+351912345678\nEMAIL:joao@exemplo.pt\nEND:VCARD", kind: .qr,
           note: "vCard 3.0 → 系统通讯录"),
    Sample(title: "09 联系人 MECARD", payload: "MECARD:N:Silva,João;TEL:912345678;EMAIL:joao@exemplo.pt;;", kind: .qr,
           note: "N 用逗号，不是分号"),
    Sample(title: "10 定位 geo", payload: "geo:38.7223,-9.1393", kind: .qr,
           note: "转 maps.apple.com 打开"),
    Sample(title: "11 日历 VEVENT", payload: "BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nSUMMARY:Reunião\nDTSTART:20261120T200000Z\nDTEND:20261120T210000Z\nEND:VEVENT\nEND:VCALENDAR", kind: .qr,
           note: "UTC 时间不偏移"),
    Sample(title: "12 SEPA 支付 EPC", payload: "BCD\n002\n1\nSCT\nBCOMPPT0\nJoao Silva\nPT50000201231234567890154\n19,99\n\nRecibo QR", kind: .qr,
           note: "BCD + 三位版本号"),
    Sample(title: "13 加密货币", payload: "bitcoin:bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kg3g4ty?amount=0.001", kind: .qr,
           note: "bitcoin: URI"),
    Sample(title: "14 裸邮箱", payload: "joao@exemplo.pt", kind: .qr,
           note: "不能误判成网址"),
    Sample(title: "15 裸域名", payload: "exemplo.pt/loja", kind: .qr,
           note: "补 https:// 打开"),

    // ── 其余 6 种码制（QR 已在上面）──
    Sample(title: "16 Aztec", payload: "Aztec-TESTE-2026", kind: .aztec,
           note: "Core Image 生成"),
    Sample(title: "17 PDF417", payload: "PDF417-TESTE-2026-LEITOR-QR-VALIDACAO-COMPLETA", kind: .pdf417,
           note: "Core Image 生成"),
    Sample(title: "18 Code 128", payload: "LEITORQR-128", kind: .code128,
           note: "静区 10 模块"),
    Sample(title: "19 EAN-13", payload: "560123456789", kind: .ean13,
           note: "12 位补校验位（应为 2）"),
    Sample(title: "20 EAN-8", payload: "1234567", kind: .ean8,
           note: "7 位补校验位"),
    Sample(title: "21 Code 39", payload: "LEITORQR", kind: .code39,
           note: "自绘表驱动"),
]

// MARK: - 布局常量

let columns = 3
let cellWidth = 760
let cellHeight = 620
let headerHeight = 150
let imageWidth = columns * cellWidth
let imageHeight = headerHeight + ((samples.count + columns - 1) / columns) * cellHeight
let maxCodeSide = 500    // 码图最大边长（含静区），必须 ≥ 短码可读尺寸

// MARK: - 生成 CGImage

func context() -> CIContext {
    CIContext(options: [.useSoftwareRenderer: false])
}

/// Core Image 二维 / Code128：整数倍放大 + 静区，输出 1:1 CGImage。
func coreImageCode(_ payload: String, kind: Kind) -> CGImage? {
    guard let data = payload.data(using: .utf8) else { return nil }
    let filter: CIFilter
    switch kind {
    case .qr:
        let f = CIFilter.qrCodeGenerator()
        f.message = data
        f.correctionLevel = "M"
        filter = f
    case .aztec:
        let f = CIFilter.aztecCodeGenerator()
        f.message = data
        filter = f
    case .pdf417:
        let f = CIFilter.pdf417BarcodeGenerator()
        f.message = data
        filter = f
    case .code128:
        let f = CIFilter.code128BarcodeGenerator()
        f.message = data
        filter = f
    default:
        return nil
    }
    guard let raw = filter.outputImage else { return nil }

    // 长负载（vCard / EPC）模块数多，按最大边长反推可用的整数倍，最小 4 倍。
    let width = raw.extent.width
    let height = raw.extent.height
    let fitted = Int(floor(CGFloat(maxCodeSide) / max(width, height)))
    let scale = max(4, min(12, fitted))
    let scaled = raw.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
    let quiet: CGFloat = kind == .code128 ? CGFloat(10 * scale) : CGFloat(4 * scale)
    let bounds = scaled.extent.insetBy(dx: -quiet, dy: -quiet).integral
    let background = CIImage(color: CIColor.white).cropped(to: bounds)
    let composed = scaled.composited(over: background)
    return context().createCGImage(composed, from: bounds)
}

// MARK: 一维码表驱动（与 BarcodeKit.swift 同一套算法）

let eanL = [
    "0001101", "0011001", "0010011", "0111101", "0100011",
    "0110001", "0101111", "0111011", "0110111", "0001011"
]
let eanG = [
    "0100111", "0110011", "0011011", "0100001", "0011101",
    "0111001", "0000101", "0010001", "0001001", "0010111"
]
let eanParity = [
    "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
    "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
]

func checkDigit(_ digits: String, fromLeft: Bool) -> Int {
    var sum = 0
    for (index, character) in digits.enumerated() {
        let digit = Int(String(character)) ?? 0
        let odd = index % 2 == 0
        sum += digit * (fromLeft ? (odd ? 1 : 3) : (odd ? 3 : 1))
    }
    return (10 - sum % 10) % 10
}

func ean13Bits(_ value: String) -> [Bool] {
    var body = value
    if body.count == 12 { body.append(String(checkDigit(body, fromLeft: true))) }
    let chars = Array(body).map(String.init)
    let parity = Array(eanParity[Int(chars[0])!])
    var bits = "101"
    for index in 0..<6 {
        let d = Int(chars[index + 1])!
        bits += parity[index] == "L" ? eanL[d] : eanG[d]
    }
    bits += "01010"
    for index in 7...12 {
        let d = Int(chars[index])!
        bits += eanL[d].map { $0 == "1" ? "0" : "1" }.joined()
    }
    bits += "101"
    return bits.map { $0 == "1" }
}

func ean8Bits(_ value: String) -> [Bool] {
    var body = value
    if body.count == 7 { body.append(String(checkDigit(body, fromLeft: false))) }
    let chars = Array(body).map(String.init)
    var bits = "101"
    for index in 0..<4 { bits += eanL[Int(chars[index])!] }
    bits += "01010"
    for index in 4..<8 {
        let d = Int(chars[index])!
        bits += eanL[d].map { $0 == "1" ? "0" : "1" }.joined()
    }
    bits += "101"
    return bits.map { $0 == "1" }
}

let code39Table: [Character: String] = [
    "0": "nnnwwnwnn", "1": "wnnwnnnnw", "2": "nnwwnnnnw", "3": "wnwwnnnnn",
    "4": "nnnwwnnnw", "5": "wnnwwnnnn", "6": "nnwwwnnnn", "7": "nnnwnnwnw",
    "8": "wnnwnnwnn", "9": "nnwwnnwnn",
    "A": "wnnnnwnnw", "B": "nnwnnwnnw", "C": "wnwnnwnnn", "D": "nnnnwwnnw",
    "E": "wnnnwwnnn", "F": "nnwnwwnnn", "G": "nnnnnwwnw", "H": "wnnnnwwnn",
    "I": "nnwnnwwnn", "J": "nnnnwwwnn", "K": "wnnnnnnww", "L": "nnwnnnnww",
    "M": "wnwnnnnwn", "N": "nnnnwnnww", "O": "wnnnwnnwn", "P": "nnwnwnnwn",
    "Q": "nnnnnnwww", "R": "wnnnnnwwn", "S": "nnwnnnwwn", "T": "nnnnwnwwn",
    "U": "wwnnnnnnw", "V": "nwwnnnnnw", "W": "wwwnnnnnn", "X": "nwnnwnnnw",
    "Y": "wwnnwnnnn", "Z": "nwwnwnnnn",
    "-": "nwnnnnwnw", ".": "wwnnnnwnn", " ": "nwwnnnwnn",
    "$": "nwnwnwnnn", "/": "nwnwnnnwn", "+": "nwnnnwnwn", "%": "nnnwnwnwn",
    "*": "nwnnwnwnn"
]

func code39Bits(_ value: String) -> [Bool] {
    let upper = value.uppercased()
    var bits: [Bool] = []
    for (index, character) in ("*" + upper + "*").enumerated() {
        if index > 0 { bits.append(false) }
        guard let pattern = code39Table[character] else { continue }
        for (elementIndex, element) in pattern.enumerated() {
            let width = element == "w" ? 3 : 1
            bits.append(contentsOf: Array(repeating: elementIndex % 2 == 0, count: width))
        }
    }
    return bits
}

/// 一维码：模块整数倍放大（宽度自适应到 maxCodeSide），条高固定，左右各 10 模块静区。
func oneDimensionalCode(_ value: String, kind: Kind) -> CGImage? {
    let bits: [Bool]
    switch kind {
    case .ean13: bits = ean13Bits(value)
    case .ean8: bits = ean8Bits(value)
    case .code39: bits = code39Bits(value)
    default: return nil
    }
    let module = max(4, Int(floor(CGFloat(maxCodeSide) / CGFloat(bits.count + 20))))
    let width = (bits.count + 20) * module
    let height = 260
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1))
    for (index, bit) in bits.enumerated() {
        if bit {
            ctx.fill(CGRect(x: (index + 10) * module, y: 0, width: module, height: height))
        }
    }
    return ctx.makeImage()
}

// MARK: - 画布合成（NSBitmapImageRep）

guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: imageWidth, pixelsHigh: imageHeight,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else {
    fatalError("无法创建画布")
}
guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("无法创建绘图上下文") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext

// 浅灰底 + 白色单元格，码区保持纯白，避免 Vision 把底色当静区。
ctx.setFillColor(CGColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(imageWidth), height: CGFloat(imageHeight)))

func drawText(_ text: String, at point: CGPoint, size: CGFloat, bold: Bool = false,
              color: CGColor = CGColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)) {
    let font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color)!]
    NSString(string: text).draw(at: NSPoint(x: point.x, y: point.y), withAttributes: attributes)
}

// AppKit 的绘制坐标原点在左下角。
func topOrigin(_ x: CGFloat, _ yFromTop: CGFloat) -> CGPoint {
    CGPoint(x: x, y: CGFloat(imageHeight) - yFromTop)
}

drawText("Leitor QR · 验收码表", at: topOrigin(48, 48), size: 40, bold: true)
drawText("12 种内容类型 + 7 种码制 + 边界负载 · 用 Vision 解码核对", at: topOrigin(50, 102), size: 20,
         color: CGColor(red: 0.35, green: 0.37, blue: 0.42, alpha: 1))

for (index, sample) in samples.enumerated() {
    let col = index % columns
    let row = index / columns
    let cellX = CGFloat(col * cellWidth + 18)
    let cellY = CGFloat(headerHeight + row * cellHeight + 12)
    let cellRect = CGRect(x: cellX, y: CGFloat(imageHeight) - cellY - CGFloat(cellHeight - 24),
                          width: CGFloat(cellWidth - 36), height: CGFloat(cellHeight - 24))

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(cellRect)
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.86, blue: 0.89, alpha: 1))
    ctx.stroke(cellRect, width: 1)

    guard let code: CGImage = {
        switch sample.kind {
        case .ean13, .ean8, .code39:
            return oneDimensionalCode(sample.payload, kind: sample.kind)
        default:
            return coreImageCode(sample.payload, kind: sample.kind)
        }
    }() else {
        print("生成失败：\(sample.title)")
        continue
    }

    // 1:1 贴图，不做任何缩放；位置取整数避免半像素插值。
    let codeX = cellX + (CGFloat(cellWidth - 36) - CGFloat(code.width)) / 2
    let codeYTop = cellY + 74
    let originY = CGFloat(imageHeight) - codeYTop - CGFloat(code.height)
    ctx.draw(code, in: CGRect(x: round(codeX), y: round(originY),
                              width: CGFloat(code.width), height: CGFloat(code.height)))

    drawText(sample.title, at: topOrigin(cellX + 22, cellY + 18), size: 21, bold: true)
    let preview = sample.payload.replacingOccurrences(of: "\n", with: " ↵ ")
    let clipped = preview.count > 62 ? String(preview.prefix(62)) + "…" : preview
    drawText(clipped, at: topOrigin(cellX + 22, cellY + CGFloat(cellHeight - 52)), size: 14,
             color: CGColor(red: 0.36, green: 0.38, blue: 0.44, alpha: 1))
    drawText(sample.note, at: topOrigin(cellX + 22, cellY + CGFloat(cellHeight - 28)), size: 14,
             color: CGColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1))
}

NSGraphicsContext.restoreGraphicsState()

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : ".build/shots/qr-test-sheet.png"
guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG 编码失败") }
try data.write(to: URL(fileURLWithPath: output))
print("已生成 \(output)  \(imageWidth)×\(imageHeight)px  \(samples.count) 个码")
