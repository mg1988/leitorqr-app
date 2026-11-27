import Foundation

/// 扫描内容的来源。
enum ScanSource: String, Codable, CaseIterable {
    case camera
    case photos
    case generator

    var localizedName: String {
        switch self {
        case .camera: return L10n.Source.camera
        case .photos: return L10n.Source.photos
        case .generator: return L10n.Source.generator
        }
    }
}
