import Foundation

/// 历史记录排序选项
enum HistorySortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case title
    case format

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return L10n.History.sortNewest
        case .oldest: return L10n.History.sortOldest
        case .title: return L10n.History.sortTitle
        case .format: return L10n.History.sortFormat
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock.arrow.downleft"
        case .oldest: return "clock.arrow.2.circlepath"
        case .title: return "textformat.abc"
        case .format: return "qrcode"
        }
    }
}

/// 历史记录来源筛选
enum HistorySourceFilter: String, CaseIterable, Identifiable {
    case all
    case camera
    case photos
    case generator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.History.sourceAll
        case .camera: return L10n.History.sourceCamera
        case .photos: return L10n.History.sourcePhotos
        case .generator: return L10n.History.sourceGenerator
        }
    }

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .camera: return "camera"
        case .photos: return "photo"
        case .generator: return "sparkles"
        }
    }

    func matches(_ record: ScanRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .camera:
            return record.source == .camera
        case .photos:
            return record.source == .photos
        case .generator:
            return record.source == .generator
        }
    }
}

/// 历史记录快捷分类过滤胶囊
enum HistoryCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case qr
    case barcode
    case website
    case wifi
    case hasNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.History.filterAll
        case .qr: return L10n.History.filterQR
        case .barcode: return L10n.History.filterBarcode
        case .website: return L10n.History.filterWebsite
        case .wifi: return L10n.History.filterWiFi
        case .hasNote: return L10n.History.filterHasNote
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .qr: return "qrcode"
        case .barcode: return "barcode"
        case .website: return "safari"
        case .wifi: return "wifi"
        case .hasNote: return "note.text"
        }
    }

    func matches(_ record: ScanRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .qr:
            return record.barcodeFormat?.isTwoDimensional ?? true
        case .barcode:
            return record.barcodeFormat?.isTwoDimensional == false
        case .website:
            return record.contentType == .url
        case .wifi:
            return record.contentType == .wifi
        case .hasNote:
            return record.trimmedNote != nil
        }
    }
}
