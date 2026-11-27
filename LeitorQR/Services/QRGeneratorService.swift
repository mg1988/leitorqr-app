import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRGeneratorError: LocalizedError, Equatable {
    case emptyInput
    case invalidURL
    case contentTooLong
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput: return L10n.Create.errorEmpty
        case .invalidURL: return L10n.Create.errorInvalidURL
        case .contentTooLong: return L10n.Create.errorTooLong
        case .generationFailed: return L10n.Create.errorFailed
        }
    }
}

/// 二维码生成（Core Image）。输出带静区、高对比度、足够分辨率的位图。
struct QRGeneratorService {

    /// UI 计数用的字符上限（兼容既有表单展示）。
    static let maxCharacterCount = 1200
    /// QR 纠错级别 H 的 Byte 模式约 1273 字节，留足余量取 1000。
    /// 中文/emoji 一个字符 3–4 字节，只按字符数判断会生成一张扫不出来的码。
    static let maxByteCount = 1000

    /// - Parameters:
    ///   - scale: 放大倍数，使用整数倍避免边缘插值模糊。
    ///   - quietZoneModules: 静区宽度（模块数）。QR 规范要求至少 4 个模块，
    ///     旧实现固定 24px 在 scale=12 时只有 2 个模块。
    func makeImage(from rawValue: String, scale: CGFloat = 12, quietZoneModules: Int = 4) throws -> UIImage {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw QRGeneratorError.emptyInput }
        guard let data = value.data(using: .utf8), data.count <= Self.maxByteCount else {
            throw QRGeneratorError.contentTooLong
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { throw QRGeneratorError.generationFailed }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let quiet = CGFloat(max(4, quietZoneModules)) * scale
        let bounds = scaled.extent.insetBy(dx: -quiet, dy: -quiet)
        let background = CIImage(color: CIColor.white).cropped(to: bounds)
        let composed = scaled.composited(over: background)

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(composed, from: bounds) else {
            throw QRGeneratorError.generationFailed
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// 校验并补全用户输入的网址。只有 http/https 才允许生成"网站"类型二维码。
    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".") else {
            return nil
        }
        return url
    }
}
