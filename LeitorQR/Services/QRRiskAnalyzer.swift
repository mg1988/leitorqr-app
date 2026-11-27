import Foundation

/// 风险等级。只表示「值得核对的程度」，绝不表示「安全 / 不安全」的结论。
enum QRRiskLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: QRRiskLevel, rhs: QRRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 一条可解释的风险特征。key/comment 交给 L10n 运行时取四语言文案。
struct QRRiskFinding {
    let level: QRRiskLevel
    let key: String
    let comment: String

    var localized: String { LanguageManager.localized(key, comment: comment) }
}

struct QRRiskAssessment {
    let level: QRRiskLevel
    let findings: [QRRiskFinding]
}

/// 端侧 QR 链接特征核对。
///
/// 设计原则：
/// 1. 零网络请求——不上传 URL，不查黑名单，与「隐私优先」定位一致。
/// 2. 只做可解释的规则命中，不做「安全/危险」判定；误报比漏报更伤信任。
/// 3. 这是扫码后的一层提示，不改变任何跳转行为，也不拦截用户操作。
enum QRRiskAnalyzer {
    static func analyze(_ url: URL) -> QRRiskAssessment {
        var findings: [QRRiskFinding] = []
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let full = url.absoluteString.lowercased()

        if scheme != "https" {
            findings.append(.init(level: .medium,
                                  key: "risk.finding.insecure",
                                  comment: "Ligação sem HTTPS"))
        }

        if isIPAddress(host) {
            findings.append(.init(level: .high,
                                  key: "risk.finding.ip",
                                  comment: "Endereço IP em vez de domínio"))
        }

        // URL 会把非 ASCII 域名转成 punycode（xn--），原始字符和 punycode 两种都要认。
        // 西里尔 а/е/о 与拉丁字母肉眼难分，是仿冒常用手法。
        if host.unicodeScalars.contains(where: { $0.value > 127 })
            || host.split(separator: ".").contains(where: { $0.lowercased().hasPrefix("xn--") }) {
            findings.append(.init(level: .high,
                                  key: "risk.finding.homograph",
                                  comment: "Domínio com caracteres não latinos"))
        }

        if shortLinkHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
            findings.append(.init(level: .medium,
                                  key: "risk.finding.shortlink",
                                  comment: "Link curto esconde o destino"))
        }

        if let tld = host.split(separator: ".").last.map(String.init), freeTLDs.contains(tld) {
            findings.append(.init(level: .medium,
                                  key: "risk.finding.tld",
                                  comment: "Domínio gratuito"))
        }

        if sensitiveKeywords.contains(where: { full.contains($0) }) {
            findings.append(.init(level: .medium,
                                  key: "risk.finding.keyword",
                                  comment: "Palavra sensível no endereço"))
        }

        // paypa1.com → paypal.com：仅在 leetspeak 归一化后撞上知名品牌、且原文不同才报。
        if looksLikeBrand(host) {
            findings.append(.init(level: .high,
                                  key: "risk.finding.lookalike",
                                  comment: "Domínio semelhante a marca conhecida"))
        }

        let labels = host.split(separator: ".")
        // punycode 的连字符是编码的一部分，不能当成仿冒特征重复报。
        if !labels.contains(where: { $0.lowercased().hasPrefix("xn--") }),
           host.filter({ $0 == "-" }).count >= 3 {
            findings.append(.init(level: .low,
                                  key: "risk.finding.hyphens",
                                  comment: "Muitos hífenes no domínio"))
        }

        let level = findings.map(\.level).max() ?? .low
        return QRRiskAssessment(level: level, findings: findings)
    }

    private static let shortLinkHosts: Set<String> = [
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd",
        "buff.ly", "cutt.ly", "rebrand.ly", "lnkd.in", "s.id", "shorte.st",
        "adf.ly", "tiny.cc", "shorturl.at", "cli.gs"
    ]

    private static let freeTLDs: Set<String> = [
        "tk", "ml", "ga", "cf", "gq", "top", "xyz", "click", "link", "icu", "pw", "su"
    ]

    private static let sensitiveKeywords: Set<String> = [
        "login", "signin", "sign-in", "verify", "verification", "password",
        "passwd", "secure", "account", "payment", "paypal", "banking", "update"
    ]

    private static let brands: Set<String> = [
        "paypal", "google", "microsoft", "apple", "netflix", "amazon",
        "instagram", "facebook", "whatsapp", "linkedin", "twitter", "icloud"
    ]

    private static func isIPAddress(_ host: String) -> Bool {
        // 去掉 IPv6 方括号再判断。
        let bare = host.hasPrefix("[") && host.hasSuffix("]")
            ? String(host.dropFirst().dropLast()) : host
        let parts = bare.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) {
            return true
        }
        return bare.contains(":") && bare.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef:").contains($0)
        }
    }

    private static func looksLikeBrand(_ host: String) -> Bool {
        let base = host.split(separator: ".").dropLast().joined(separator: ".")
        guard !base.isEmpty else { return false }
        let normalized = base
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "l")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "rn", with: "m")
            .replacingOccurrences(of: "-", with: "")
        // 归一化后变化才算仿冒（避免把正常的 paypal.com 自己报出来）；
        // 用 contains 而非相等，覆盖 app1e-id → appleid、paypa1-secure → paypalsecure。
        guard normalized != base else { return false }
        return brands.contains(where: { normalized.contains($0) || normalized.hasPrefix($0) })
    }
}
