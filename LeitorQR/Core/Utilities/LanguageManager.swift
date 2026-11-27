import Foundation
import SwiftUI

/// App 内语言选择。首发四个市场：巴西、中国、美国、日本。
/// - `.system` 跟随系统语言（由系统按 `CFBundleLocalizations` 选择）；
/// - 其余四项显式指定 Bundle，切换后立即生效，无需重启 App。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ptBR
    case zhHans
    case english
    case japanese

    var id: String { rawValue }

    /// 对应编译产物里的 `.lproj` 目录名；`.system` 返回 nil 表示用 Bundle.main。
    var lprojName: String? {
        switch self {
        case .system: return nil
        case .ptBR: return "pt-BR"
        case .zhHans: return "zh-Hans"
        case .english: return "en"
        case .japanese: return "ja"
        }
    }

    /// 语言名用该语言自身书写，四种语言下都能看懂，不依赖当前界面语言。
    var nativeName: String {
        switch self {
        case .system: return "Seguir o sistema"
        case .ptBR: return "Português (Brasil)"
        case .zhHans: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    /// 副标题：地区/说明，便于识别。
    var detail: String {
        switch self {
        case .system: return "Automático"
        case .ptBR: return "Brasil"
        case .zhHans: return "中国"
        case .english: return "United States"
        case .japanese: return "日本"
        }
    }
}

/// App 内语言切换管理。
///
/// 为什么不用 `Bundle.main` + 系统语言：`String(localized:)` 只认系统首选语言，
/// App 内改不了；显式语言必须用 `String(localized: bundle:)` 指向对应 `.lproj`。
/// 所有 `L10n` 条目因此从 `static let` 改为 `static var`，每次读取都取当前 Bundle，
/// 语言切换后调用 `reload()` 让视图树重建即可全文刷新。
final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    private let storageKey = "com.leitorqr.appLanguage"

    @Published private(set) var current: AppLanguage

    /// 每次切换自增，用作根视图的 `.id()`，强制重建整棵视图树以重新读取所有 `L10n` 值。
    @Published private(set) var revision: Int = 0

    private init() {
        let raw = UserDefaults.standard.string(forKey: "com.leitorqr.appLanguage")
        self.current = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// 当前文案 Bundle。`.system` 交给系统，其余指向显式 `.lproj`。
    var bundle: Bundle {
        guard let name = current.lprojName,
              let path = Bundle.main.path(forResource: name, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    /// 供 UI 显示的短名（当前生效语言，跟随系统时显示系统解析结果）。
    var displayName: String {
        if current != .system { return current.nativeName }
        let preferred = Locale.preferredLanguages.first ?? "pt-BR"
        let lower = preferred.lowercased()
        if lower.hasPrefix("zh") { return AppLanguage.zhHans.nativeName }
        if lower.hasPrefix("ja") { return AppLanguage.japanese.nativeName }
        if lower.hasPrefix("en") { return AppLanguage.english.nativeName }
        return AppLanguage.ptBR.nativeName
    }

    /// 日期/数字格式化用的 Locale。
    ///
    /// `Date.formatted()` 只认系统 Locale，App 内切到英文后日期仍会按葡语写，
    /// 结果页里「20/11/2026」和「Nov 20, 2026」混着出现。这里统一按当前语言给。
    var locale: Locale {
        switch current {
        case .system: return .autoupdatingCurrent
        case .ptBR: return Locale(identifier: "pt_BR")
        case .zhHans: return Locale(identifier: "zh_Hans_CN")
        case .english: return Locale(identifier: "en_US")
        case .japanese: return Locale(identifier: "ja_JP")
        }
    }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        revision += 1
    }

    /// 读取一条本地化文案。所有 `L10n` 条目都经这里，保证切换后立即生效。
    /// 用 `NSLocalizedString(_:bundle:value:comment:)` 而非 `String(localized:)`：
    /// 后者的 key 参数是 `StaticString`，不接受运行时变量；前者支持显式 Bundle，
    /// 这正是 App 内切换语言（不重启）的关键。
    static func localized(_ key: String, comment: String) -> String {
        NSLocalizedString(key, bundle: shared.bundle, value: key, comment: comment)
    }
}
