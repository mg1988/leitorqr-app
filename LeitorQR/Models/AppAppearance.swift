import SwiftUI

/// 全局外观模式：跟随系统、浅色、深色。
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    static let storageKey = "app_appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.Settings.appearanceSystem
        case .light: return L10n.Settings.appearanceLight
        case .dark: return L10n.Settings.appearanceDark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
