import Foundation
import SwiftUI

/// App 内语言选择（11-27：全球上架，30 种语言 / 地区）。
/// - `.system` 跟随系统语言（由系统按 `CFBundleLocalizations` 选择最匹配的 .lproj）；
/// - 其余显式指定 Bundle，切换后立即生效，无需重启 App。
/// - rawValue 会存进 UserDefaults：老的五个（system / ptBR / zhHans / english / japanese）不能改，
///   新加的直接用 .lproj 代码。
/// - 同一种语言按国家分开（es / es-419、fr / fr-CA、pt-BR / pt-PT、en / en-GB、zh-Hans / zh-Hant），
///   文案是各地母语写手分别写的，不是互相转换。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case englishUK = "en-GB"
    case spanish = "es"
    case spanishLatinAmerica = "es-419"
    case french = "fr"
    case frenchCanada = "fr-CA"
    case german = "de"
    case italian = "it"
    case ptBR
    case portuguesePortugal = "pt-PT"
    case dutch = "nl"
    case polish = "pl"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "nb"
    case finnish = "fi"
    case russian = "ru"
    case ukrainian = "uk"
    case turkish = "tr"
    case arabic = "ar"
    case hebrew = "he"
    case hindi = "hi"
    case indonesian = "id"
    case malay = "ms"
    case vietnamese = "vi"
    case thai = "th"
    case korean = "ko"
    case japanese
    case zhHans
    case chineseTraditional = "zh-Hant"

    var id: String { rawValue }

    /// 对应编译产物里的 `.lproj` 目录名；`.system` 返回 nil 表示用 Bundle.main。
    var lprojName: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .englishUK: return "en-GB"
        case .spanish: return "es"
        case .spanishLatinAmerica: return "es-419"
        case .french: return "fr"
        case .frenchCanada: return "fr-CA"
        case .german: return "de"
        case .italian: return "it"
        case .ptBR: return "pt-BR"
        case .portuguesePortugal: return "pt-PT"
        case .dutch: return "nl"
        case .polish: return "pl"
        case .swedish: return "sv"
        case .danish: return "da"
        case .norwegian: return "nb"
        case .finnish: return "fi"
        case .russian: return "ru"
        case .ukrainian: return "uk"
        case .turkish: return "tr"
        case .arabic: return "ar"
        case .hebrew: return "he"
        case .hindi: return "hi"
        case .indonesian: return "id"
        case .malay: return "ms"
        case .vietnamese: return "vi"
        case .thai: return "th"
        case .korean: return "ko"
        case .japanese: return "ja"
        case .zhHans: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        }
    }

    /// 语言名用该语言自身书写：不管当前界面是什么语言，用户都能认出自己的语言。
    var nativeName: String {
        switch self {
        case .system: return L10n.Settings.appearanceSystem
        case .english: return "English (US)"
        case .englishUK: return "English (UK)"
        case .spanish: return "Español (España)"
        case .spanishLatinAmerica: return "Español (Latinoamérica)"
        case .french: return "Français (France)"
        case .frenchCanada: return "Français (Canada)"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .ptBR: return "Português (Brasil)"
        case .portuguesePortugal: return "Português (Portugal)"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .swedish: return "Svenska"
        case .danish: return "Dansk"
        case .norwegian: return "Norsk bokmål"
        case .finnish: return "Suomi"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        case .turkish: return "Türkçe"
        case .arabic: return "العربية"
        case .hebrew: return "עברית"
        case .hindi: return "हिन्दी"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .vietnamese: return "Tiếng Việt"
        case .thai: return "ไทย"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        case .zhHans: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }

    /// 副标题：地区（用该语言书写，空字符串 = 不显示）。跟随系统时显示系统实际选中的语言。
    var detail: String {
        switch self {
        case .system: return LanguageManager.resolvedSystemLanguage.nativeName
        case .english: return "United States"
        case .englishUK: return "United Kingdom"
        case .spanish: return "España"
        case .spanishLatinAmerica: return "México y Latinoamérica"
        case .french: return "France"
        case .frenchCanada: return "Canada"
        case .german: return "Deutschland · Österreich · Schweiz"
        case .italian: return "Italia"
        case .ptBR: return "Brasil"
        case .portuguesePortugal: return "Portugal"
        case .dutch: return "Nederland · België"
        case .polish: return "Polska"
        case .swedish: return "Sverige"
        case .danish: return "Danmark"
        case .norwegian: return "Norge"
        case .finnish: return "Suomi"
        case .russian: return ""
        case .ukrainian: return "Україна"
        case .turkish: return "Türkiye"
        case .arabic: return ""
        case .hebrew: return "ישראל"
        case .hindi: return "भारत"
        case .indonesian: return "Indonesia"
        case .malay: return "Malaysia"
        case .vietnamese: return "Việt Nam"
        case .thai: return "ประเทศไทย"
        case .korean: return "대한민국"
        case .japanese: return "日本"
        case .zhHans: return "中国大陆"
        case .chineseTraditional: return "台灣"
        }
    }

    /// 日期 / 数字格式用的 Locale。
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en_US"
        case .englishUK: return "en_GB"
        case .spanish: return "es_ES"
        case .spanishLatinAmerica: return "es_MX"
        case .french: return "fr_FR"
        case .frenchCanada: return "fr_CA"
        case .german: return "de_DE"
        case .italian: return "it_IT"
        case .ptBR: return "pt_BR"
        case .portuguesePortugal: return "pt_PT"
        case .dutch: return "nl_NL"
        case .polish: return "pl_PL"
        case .swedish: return "sv_SE"
        case .danish: return "da_DK"
        case .norwegian: return "nb_NO"
        case .finnish: return "fi_FI"
        case .russian: return "ru_RU"
        case .ukrainian: return "uk_UA"
        case .turkish: return "tr_TR"
        case .arabic: return "ar_AE"
        case .hebrew: return "he_IL"
        case .hindi: return "hi_IN"
        case .indonesian: return "id_ID"
        case .malay: return "ms_MY"
        case .vietnamese: return "vi_VN"
        case .thai: return "th_TH"
        case .korean: return "ko_KR"
        case .japanese: return "ja_JP"
        case .zhHans: return "zh_Hans_CN"
        case .chineseTraditional: return "zh_Hant_TW"
        }
    }

    /// 从右往左书写的语言（阿拉伯语、希伯来语）：整棵视图树镜像。
    var isRightToLeft: Bool {
        self == .arabic || self == .hebrew
    }

    /// 按 .lproj 代码找语言（大小写不敏感）。只有语言没有地区的（如 `pt`），匹配同语言的第一个。
    static func matching(lproj code: String) -> AppLanguage? {
        let lower = code.lowercased().replacingOccurrences(of: "_", with: "-")
        if let exact = allCases.first(where: { $0.lprojName?.lowercased() == lower }) { return exact }
        let base = lower.split(separator: "-").first.map(String.init) ?? lower
        return allCases.first { $0.lprojName?.lowercased().hasPrefix(base) == true }
    }
}

/// App 内语言切换管理。
///
/// 为什么不用 `Bundle.main` + 系统语言：`String(localized:)` 只认系统首选语言，
/// App 内改不了；显式语言必须用 `NSLocalizedString(_:bundle:)` 指向对应 `.lproj`。
/// 所有 `L10n` 条目因此是 `static var`，每次读取都取当前 Bundle，
/// 语言切换后 `revision` 自增让根视图重建即可全文刷新。
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

    /// 跟随系统时，系统实际为本 App 选中的语言（按 CFBundleLocalizations + 用户的系统语言顺序）。
    static var resolvedSystemLanguage: AppLanguage {
        let chosen = Bundle.main.preferredLocalizations.first ?? "pt-BR"
        return AppLanguage.matching(lproj: chosen) ?? .ptBR
    }

    /// 当前实际生效的语言（跟随系统时解析成具体语言）。
    var effective: AppLanguage {
        current == .system ? Self.resolvedSystemLanguage : current
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

    /// 供 UI 显示的短名（当前生效语言）。
    var displayName: String {
        effective.nativeName
    }

    /// 日期 / 数字格式化用的 Locale。跟随系统时用系统 Locale。
    var locale: Locale {
        guard let identifier = current.localeIdentifier else { return .autoupdatingCurrent }
        return Locale(identifier: identifier)
    }

    /// 整棵视图树的书写方向。App 内选了阿拉伯语 / 希伯来语但系统是从左往右时，
    /// 系统不会自动镜像，要在根视图上显式设置。
    var layoutDirection: LayoutDirection {
        effective.isRightToLeft ? .rightToLeft : .leftToRight
    }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        revision += 1
    }

    /// 读取一条本地化文案。所有 `L10n` 条目都经这里，保证切换后立即生效。
    static func localized(_ key: String, comment: String) -> String {
        NSLocalizedString(key, bundle: shared.bundle, value: key, comment: comment)
    }
}
