import AVFoundation
import Vision

/// 首发声明的可识别码制。新增格式时必须同时在 `avMetadataType` 与 `vnSymbology` 中登记，
/// 并确认真机可识别——不得在 UI 中宣称未验证的格式。
enum BarcodeFormat: String, CaseIterable, Codable, Hashable, Identifiable {
    case qrCode
    case ean8
    case ean13
    case upce
    case code128
    case code39
    case pdf417
    case aztec
    case dataMatrix

    var id: String { rawValue }

    /// 摄像头元数据输出使用的类型。
    var avMetadataType: AVMetadataObject.ObjectType {
        switch self {
        case .qrCode: return .qr
        case .ean8: return .ean8
        case .ean13: return .ean13
        case .upce: return .upce
        case .code128: return .code128
        case .code39: return .code39
        case .pdf417: return .pdf417
        case .aztec: return .aztec
        case .dataMatrix: return .dataMatrix
        }
    }

    /// 相册识别（Vision）使用的码制。
    var vnSymbology: VNBarcodeSymbology {
        switch self {
        case .qrCode: return .qr
        case .ean8: return .ean8
        case .ean13: return .ean13
        case .upce: return .upce
        case .code128: return .code128
        case .code39: return .code39
        case .pdf417: return .pdf417
        case .aztec: return .aztec
        case .dataMatrix: return .dataMatrix
        }
    }

    /// 展示名。码制属于技术术语，保持国际写法（pt-PT 下同样使用）。
    var displayName: String {
        switch self {
        case .qrCode: return "QR Code"
        case .ean8: return "EAN-8"
        case .ean13: return "EAN-13"
        case .upce: return "UPC-E"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        }
    }

    /// 是否为二维条码（用于结果页的类型判定）。
    var isTwoDimensional: Bool {
        switch self {
        case .qrCode, .pdf417, .aztec, .dataMatrix: return true
        case .ean8, .ean13, .upce, .code128, .code39: return false
        }
    }

    /// 能否用本机生成器重画。`UPC-E` / `Data Matrix` 只能扫不能生成，
    /// 历史里这类记录就不画缩略图，免得给出一张假的码。
    var barcodeKind: BarcodeKind? {
        switch self {
        case .qrCode: return .qr
        case .aztec: return .aztec
        case .pdf417: return .pdf417
        case .code128: return .code128
        case .ean13: return .ean13
        case .ean8: return .ean8
        case .code39: return .code39
        case .upce, .dataMatrix: return nil
        }
    }

    static func from(avMetadataType rawValue: String) -> BarcodeFormat? {
        allCases.first { $0.avMetadataType.rawValue == rawValue }
    }

    static func from(vnSymbology symbology: VNBarcodeSymbology) -> BarcodeFormat? {
        allCases.first { $0.vnSymbology == symbology }
    }
}
