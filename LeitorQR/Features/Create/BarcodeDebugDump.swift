#if DEBUG
import Foundation
import UIKit

/// 仅 Debug：把 7 种码制各渲染一张 PNG 到 Documents，供命令行用 Vision 解码验收。
///
/// 为什么不直接截屏解码：屏截会把 460px 宽的条码非整数倍放大到 990px，
/// 模块边界被拉伸后解码器可能认不出——那是**显示缩放**的问题，不是生成逻辑的问题。
/// 拿原始位图来判"生成的码对不对"，跟"在屏幕上好不好看"分开验。
enum BarcodeDebugDump {

    /// `LEITORQR_DUMP_BARCODES=1` 时执行一次。
    @MainActor
    static func runIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        let dumpAll = env["LEITORQR_DUMP_BARCODES"] == "1"
        let dumpWifi = env["LEITORQR_DUMP_WIFI"] == "1"
        guard dumpAll || dumpWifi else { return }

        let samples: [(BarcodeKind, String)] = [
            (.qr, "https://exemplo.pt"),
            (.aztec, "https://exemplo.pt"),
            (.pdf417, "LEITOR-QR-PDF417-2026"),
            (.code128, "ABC-123456"),
            // 带完整校验位的 EAN-13，顺带走一遍"校验位校验"分支。
            (.ean13, "5901234123457"),
            // 不带校验位，走自动补位分支。
            (.ean8, "9638507"),
            (.code39, "ABC-123")
        ]

        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        for (kind, value) in samples {
            guard let image = try? BarcodeImageGenerator.render(value: value, kind: kind),
                  let data = image.pngData() else {
                continue
            }
            try? data.write(to: dir.appendingPathComponent("\(kind.rawValue).png"))
        }

        dumpLengthMatrix(into: dir)
        guard dumpAll else { return }
        dumpStyled(into: dir)
        dumpTemplates(into: dir)
        NSLog("BARCODE_DUMP %@", dir.path)
    }

    /// `LEITORQR_DUMP_WIFI=1`：按「内容长度 × 码点形状」铺一组 Wi-Fi 负载。
    ///
    /// Wi-Fi 的 payload（`WIFI:T:WPA;S:…;P:…;;`）天生就 30 字符起步，
    /// 正好落在自绘圆角码点解码不稳的区间里。这一组用来定位「多长开始扫不出、
    /// 换 square 能不能救回来」，而不是拿一个样本碰运气。
    @MainActor
    private static func dumpLengthMatrix(into dir: URL) {
        guard ProcessInfo.processInfo.environment["LEITORQR_DUMP_WIFI"] == "1" else { return }

        let payloads: [(String, String)] = [
            ("w27", "WIFI:T:WPA;S:Casa;P:senha;;"),
            ("w37", "WIFI:T:WPA;S:MinhaCasa;P:senha12345;;"),
            ("w45", "WIFI:T:WPA;S:Casa-do-Joao;P:senha1234567890;;"),
            ("w56", "WIFI:T:WPA;S:Rede-do-Escritorio;P:umaSenhaBemLonga2026;;"),
            ("w70", "WIFI:T:WPA;S:Rede-do-Escritorio-Principal;P:umaSenhaBemLonga2026;;"),
            ("w85", "WIFI:T:WPA2-EAP;S:Universidade-Faculdade-Engenharia;P:senhaSuperSecreta2026!;H:true;;"),
            ("url70", "https://exemplo.pt/pagina/muito/comprida?utm=abc&id=1234567890&ref=xyz")
        ]
        let shapes: [DotShape] = [.square, .rounded, .circle]

        for (name, value) in payloads {
            for shape in shapes {
                var style = QRCodeStyle()
                style.dotShape = shape
                do {
                    let image = try BarcodeImageGenerator.render(value: value, kind: .qr, style: style)
                    guard let data = image.pngData() else { continue }
                    try data.write(to: dir.appendingPathComponent("len_\(name)_\(shape.rawValue).png"))
                } catch {
                    NSLog("BARCODE_DUMP len_%@_%@ failed", name, shape.rawValue)
                }
            }
        }
    }

    /// 模板外围画了一圈装饰，必须用真解码器验一遍：装饰有没有吃掉定位角、
    /// 码区静区够不够、深色画布会不会让 Vision 找不到边界。
    @MainActor
    private static func dumpTemplates(into dir: URL) {
        for template in CodeTemplate.all {
            let id = template.id
            let short = id.replacingOccurrences(of: "-", with: "_")
            // 固定用与 qr.png 同量级的短内容做基线：这一组要验的是
            // 「模板装饰会不会破坏一个本来能扫的码」，变量只能留一个。
            // 长度的边界另由 dumpLengthMatrix 单独铺（27→85 字符 × 三种码点形状），
            // 两组分开跑才能分清「是装饰吃掉了码」还是「长内容本来就解不出」。
            let value = "https://exemplo.pt"
            let style = template.applying(to: QRCodeStyle())

            do {
                let image = try BarcodeImageGenerator.render(
                    value: value,
                    kind: .qr,
                    style: style
                )
                if let data = image.pngData() {
                    try data.write(to: dir.appendingPathComponent("template_\(short).png"))
                }
            } catch {
                NSLog("BARCODE_DUMP template_%@ failed: %@", short, String(describing: error))
            }

            // 同内容、同码制的黑白对照：确认这批基线码本身能扫。
            // 模板图检不出时先看对照——对照也挂了就说明问题不在装饰。
            do {
                let plain = try BarcodeImageGenerator.render(
                    value: value,
                    kind: .qr,
                    style: QRCodeStyle()
                )
                if let data = plain.pngData() {
                    try data.write(to: dir.appendingPathComponent("plain_\(short).png"))
                }
            } catch {
                NSLog("BARCODE_DUMP plain_%@ failed: %@", short, String(describing: error))
            }
        }
    }

    /// 样式化后的码还能不能扫？圆点会啃掉每个模块的边角、中心图标又挖掉一块，
    /// 这两件事都在消耗纠错冗余——必须用真解码器验一遍，不能靠肉眼觉得"看起来还行"。
    @MainActor
    private static func dumpStyled(into dir: URL) {
        var circleLogo = QRCodeStyle()
        circleLogo.dotShape = .circle
        circleLogo.logoSource = .brand
        circleLogo.foregroundHex = 0x1B2A4A

        var brandColor = QRCodeStyle()
        brandColor.dotShape = .rounded
        brandColor.foregroundHex = 0x246BCE
        brandColor.backgroundHex = 0xF7F3EA

        var tintedBars = QRCodeStyle()
        tintedBars.foregroundHex = 0x0E5C55
        tintedBars.backgroundHex = 0xEFF2F6

        let logo = BrandMarkRenderer.logo(for: .instagram, side: 84, color: circleLogo.foreground)

        var customLogoStyle = QRCodeStyle()
        customLogoStyle.dotShape = .circle
        customLogoStyle.logoSource = .custom

        let styled: [(String, BarcodeKind, String, QRCodeStyle, UIImage?)] = [
            ("qr_circle_logo", .qr, "https://exemplo.pt", circleLogo, logo),
            ("qr_custom_logo", .qr, "https://exemplo.pt", customLogoStyle, DebugLogoImage.make()),
            ("qr_brand_color", .qr, "https://exemplo.pt/estilo", brandColor, nil),
            ("aztec_tinted", .aztec, "https://exemplo.pt", brandColor, nil),
            ("pdf417_tinted", .pdf417, "LEITOR-QR-PDF417-2026", tintedBars, nil),
            ("code128_tinted", .code128, "ABC-123456", tintedBars, nil),
            ("ean13_tinted", .ean13, "5901234123457", tintedBars, nil)
        ]

        for (name, kind, value, style, mark) in styled {
            do {
                let image = try BarcodeImageGenerator.render(
                    value: value,
                    kind: kind,
                    style: style,
                    logo: mark
                )
                guard let data = image.pngData() else {
                    NSLog("BARCODE_DUMP %@ pngData nil", name)
                    continue
                }
                try data.write(to: dir.appendingPathComponent("\(name).png"))
            } catch {
                NSLog("BARCODE_DUMP %@ failed: %@", name, String(describing: error))
            }
        }
    }
}
#endif
