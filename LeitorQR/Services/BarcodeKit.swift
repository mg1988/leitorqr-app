import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 可生成的码制。
///
/// 分两类：
/// - **二维**（QR / Aztec / PDF417 / Code 128 之外的那些）：由 Core Image 直接绘制。
/// - **一维**：Core Image 只提供 Code 128，EAN-13 / EAN-8 / Code 39 没有系统生成器，
///   本文件按规范自己算模块序列再画（表驱动，见各 `modules(for:)`）。
enum BarcodeKind: String, CaseIterable, Identifiable {
    case qr
    case aztec
    case pdf417
    case code128
    case ean13
    case ean8
    case code39

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qr: return "QR"
        case .aztec: return "Aztec"
        case .pdf417: return "PDF417"
        case .code128: return "Code 128"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .code39: return "Code 39"
        }
    }

    /// 一维码对内容有硬约束（纯数字 / 大写字母数字），表单要据此给出提示。
    var isOneDimensional: Bool {
        switch self {
        case .qr, .aztec, .pdf417: return false
        case .code128, .ean13, .ean8, .code39: return true
        }
    }

    /// 只接受数字的码制——输入框直接给数字键盘。
    var acceptsDigitsOnly: Bool {
        switch self {
        case .ean13, .ean8: return true
        default: return false
        }
    }

    /// 创建页"条形码"分区里列出的一维码制。
    static var oneDimensional: [BarcodeKind] {
        [.ean13, .ean8, .code128, .code39]
    }

    /// 一维码只有数字和横排条码，预览需要横向铺满。
    var aspectHint: String {
        isOneDimensional ? "wide" : "square"
    }

    /// 写进历史时记成哪种格式。历史读回来要靠它决定用哪个生成器重画缩略图。
    var barcodeFormat: BarcodeFormat {
        switch self {
        case .qr: return .qrCode
        case .aztec: return .aztec
        case .pdf417: return .pdf417
        case .code128: return .code128
        case .ean13: return .ean13
        case .ean8: return .ean8
        case .code39: return .code39
        }
    }
}

enum BarcodeGenerationError: LocalizedError, Equatable {
    case emptyInput
    case contentTooLong
    case needsDigits(String)
    case checksumFailed
    case unsupportedCharacters(String)
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return L10n.Create.errorEmpty
        case .contentTooLong:
            return L10n.Create.errorTooLong
        case .needsDigits(let counts):
            return L10n.Create.errorNeedsDigits(counts)
        case .checksumFailed:
            return L10n.Create.errorChecksum
        case .unsupportedCharacters(let allowed):
            return L10n.Create.errorUnsupportedChars(allowed)
        case .generationFailed:
            return L10n.Create.errorFailed
        }
    }
}

/// 把字符串渲染成指定码制的位图。
enum BarcodeImageGenerator {

    /// 二维码放大倍数（模块 → 像素），整数倍避免边缘插值模糊。
    /// 与 `QRGeneratorService` 保持一致，同一份内容换码制后视觉重量不跳。
    private static let twoDimensionalScale: CGFloat = 12
    /// 一维码的模块宽度（像素）。4 在分享尺寸下仍能被常见扫码器识别。
    private static let moduleWidth: CGFloat = 4
    /// 一维码条高（像素）。
    private static let barHeight: CGFloat = 170
    /// 一维码静区宽度（模块数），规范要求左右各 ≥10。
    private static let oneDimensionalQuietZone = 10

    static func render(
        value: String,
        kind: BarcodeKind,
        style: QRCodeStyle = QRCodeStyle(),
        logo: UIImage? = nil,
        scale: CGFloat? = nil
    ) throws -> UIImage {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BarcodeGenerationError.emptyInput }

        switch kind {
        case .qr:
            // 二维码自己画：Core Image 出不了圆点、改不了颜色、也放不进图标。
            let base = try QRCodeRenderer.render(value: trimmed, style: style, logo: logo, scale: scale)
            // 模板卡片在这一层合成，而不是在预览视图里叠 SwiftUI：
            // 预览、存相册、分享、历史重画走的是同一个 render，天然一致。
            guard let template = style.template else { return base }
            return TemplateRenderer.compose(code: base, template: template)
        case .aztec, .pdf417, .code128:
            return try renderCoreImage(value: trimmed, kind: kind, style: style)
        case .ean13, .ean8, .code39:
            let modules = try modules(for: trimmed, kind: kind)
            return drawOneDimensional(modules: modules, style: style)
        }
    }

    // MARK: - Core Image 路径

    private static func renderCoreImage(
        value: String,
        kind: BarcodeKind,
        style: QRCodeStyle
    ) throws -> UIImage {
        guard let data = value.data(using: .utf8) else {
            throw BarcodeGenerationError.generationFailed
        }
        let filter: CIFilter
        switch kind {
        case .qr:
            let qr = CIFilter.qrCodeGenerator()
            qr.message = data
            qr.correctionLevel = "M"
            filter = qr
        case .aztec:
            let aztec = CIFilter.aztecCodeGenerator()
            aztec.message = data
            filter = aztec
        case .pdf417:
            let pdf = CIFilter.pdf417BarcodeGenerator()
            pdf.message = data
            filter = pdf
        case .code128:
            guard value.allSatisfy({ $0.isASCII }) else {
                throw BarcodeGenerationError.unsupportedCharacters("ASCII")
            }
            let code = CIFilter.code128BarcodeGenerator()
            code.message = data
            filter = code
        default:
            throw BarcodeGenerationError.generationFailed
        }

        guard let rawOutput = filter.outputImage else {
            throw BarcodeGenerationError.generationFailed
        }

        // 生成器只出黑白，换色靠 falseColor 把暗部/亮部各自映射到自定义颜色。
        let tinted: CIImage
        if style.foregroundHex == 0x111418 && style.backgroundHex == 0xFFFFFF {
            tinted = rawOutput
        } else {
            let falseColor = CIFilter.falseColor()
            falseColor.inputImage = rawOutput
            falseColor.color0 = CIColor(color: UIColor(style.foreground))
            falseColor.color1 = CIColor(color: UIColor(style.background))
            tinted = falseColor.outputImage ?? rawOutput
        }

        let scaled = tinted.transformed(by: CGAffineTransform(scaleX: twoDimensionalScale, y: twoDimensionalScale))
        // 静区按"模块数 × 放大倍数"算：二维 4 个模块（规范下限），
        // Code 128 走同一路径但规范要求左右各 10 个模块。
        let quietModules: CGFloat = kind == .code128 ? 10 : 4
        let quiet = quietModules * twoDimensionalScale
        let bounds = scaled.extent.insetBy(dx: -quiet, dy: -quiet)
        let background = CIImage(color: CIColor(color: UIColor(style.background))).cropped(to: bounds)
        let composed = scaled.composited(over: background)

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(composed, from: bounds) else {
            throw BarcodeGenerationError.generationFailed
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    // MARK: - 一维码

    private static func drawOneDimensional(modules: [Bool], style: QRCodeStyle) -> UIImage {
        let quiet = oneDimensionalQuietZone
        let totalWidth = CGFloat(modules.count + quiet * 2) * moduleWidth
        let size = CGSize(width: totalWidth, height: barHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(style.background).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(style.foreground).setFill()

            var x = CGFloat(quiet) * moduleWidth
            for module in modules {
                if module {
                    context.fill(CGRect(x: x, y: 0, width: moduleWidth, height: barHeight))
                }
                x += moduleWidth
            }
        }
    }

    /// 生成"模块序列"（true = 黑）。
    private static func modules(for value: String, kind: BarcodeKind) throws -> [Bool] {
        switch kind {
        case .ean13: return try ean13Modules(value)
        case .ean8: return try ean8Modules(value)
        case .code39: return try code39Modules(value)
        default: throw BarcodeGenerationError.generationFailed
        }
    }

    // MARK: EAN-13 / EAN-8

    /// 左侧奇校验（L）、左侧偶校验（G）、右侧（R，L 的反码）。
    private static let eanL = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    ]
    private static let eanG = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    ]
    private static let eanParity = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
    ]

    private static func ean13Modules(_ value: String) throws -> [Bool] {
        let digits = try validDigits(value, allowedCounts: [12, 13])
        var body = digits
        if body.count == 12 {
            body.append(String(eanCheckDigit(body, fromLeft: true)))
        } else {
            let expected = eanCheckDigit(String(body.dropLast()), fromLeft: true)
            guard expected == body.last?.wholeNumberValue else {
                throw BarcodeGenerationError.checksumFailed
            }
        }

        let chars = body.map(String.init)
        // validDigits 已保证全 ASCII 0-9，但这里不靠上游校验活着：统一走 guard-throw。
        let numbers = chars.compactMap { Int($0) }
        guard numbers.count == chars.count, let first = numbers.first else {
            throw BarcodeGenerationError.unsupportedCharacters("0-9")
        }
        let parity = Array(eanParity[first])
        var bits = "101"

        for index in 0..<6 {
            let digit = numbers[index + 1]
            bits += parity[index] == "L" ? eanL[digit] : eanG[digit]
        }
        bits += "01010"
        for index in 7...12 {
            let digit = numbers[index]
            bits += eanL[digit].map { $0 == "1" ? "0" : "1" }.reduce("", +)
        }
        bits += "101"

        return bits.map { $0 == "1" }
    }

    private static func ean8Modules(_ value: String) throws -> [Bool] {
        let digits = try validDigits(value, allowedCounts: [7, 8])
        var body = digits
        if body.count == 7 {
            body.append(String(eanCheckDigit(body, fromLeft: false)))
        } else {
            let expected = eanCheckDigit(String(body.dropLast()), fromLeft: false)
            guard expected == body.last?.wholeNumberValue else {
                throw BarcodeGenerationError.checksumFailed
            }
        }

        let chars = body.map(String.init)
        let numbers = chars.compactMap { Int($0) }
        guard numbers.count == chars.count else {
            throw BarcodeGenerationError.unsupportedCharacters("0-9")
        }
        var bits = "101"
        for index in 0..<4 {
            bits += eanL[numbers[index]]
        }
        bits += "01010"
        for index in 4..<8 {
            bits += eanL[numbers[index]].map { $0 == "1" ? "0" : "1" }.reduce("", +)
        }
        bits += "101"
        return bits.map { $0 == "1" }
    }

    /// 校验位。EAN-13 从左起奇数位权重 1、偶数位 3；EAN-8 反过来。
    private static func eanCheckDigit(_ digits: String, fromLeft: Bool) -> Int {
        let values = digits.compactMap { $0.wholeNumberValue }
        var sum = 0
        for (index, digit) in values.enumerated() {
            let odd = (index % 2 == 0)
            let weight = fromLeft ? (odd ? 1 : 3) : (odd ? 3 : 1)
            sum += digit * weight
        }
        return (10 - sum % 10) % 10
    }

    private static func validDigits(_ value: String, allowedCounts: [Int]) throws -> String {
        // `Character.isNumber` 对全角数字、罗马数字、分数也为真，
        // 后面 `Int(String(...))!` 会直接崩、`wholeNumberValue` 则会静默丢字符算错校验位。
        // EAN 只接受 ASCII 0-9，按 Unicode scalar 严格校验。
        guard value.unicodeScalars.allSatisfy({ (UInt32(0x30)...UInt32(0x39)).contains($0.value) }) else {
            throw BarcodeGenerationError.unsupportedCharacters("0-9")
        }
        guard allowedCounts.contains(value.count) else {
            let counts = allowedCounts.map(String.init).joined(separator: "/")
            throw BarcodeGenerationError.needsDigits(counts)
        }
        return value
    }

    // MARK: Code 39

    /// 每个字符 9 个元素（条/空交替，从条开始），n=窄 w=宽，其中 3 个为宽。
    private static let code39Table: [Character: String] = [
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

    private static func code39Modules(_ value: String) throws -> [Bool] {
        let upper = value.uppercased()
        let allowed = Set(code39Table.keys).filter { $0 != "*" }
        guard upper.allSatisfy({ code39Table[$0] != nil && $0 != "*" }) else {
            let preview = String(allowed.sorted().prefix(20))
            throw BarcodeGenerationError.unsupportedCharacters(preview)
        }
        guard upper.count <= 40 else { throw BarcodeGenerationError.contentTooLong }

        var bits: [Bool] = []
        // 起始符 + 字符 + 终止符，字符之间用一条窄空隔开
        for (index, character) in ("*" + upper + "*").enumerated() {
            if index > 0 { bits.append(false) }
            guard let pattern = code39Table[character] else { continue }
            // 每个字符的 9 个元素按"条、空、条、空…"交替展开
            for (elementIndex, element) in pattern.enumerated() {
                let width = element == "w" ? 3 : 1
                bits.append(contentsOf: Array(repeating: elementIndex % 2 == 0, count: width))
            }
        }
        return bits
    }
}
