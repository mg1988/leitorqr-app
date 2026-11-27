import Foundation

/// 扫描内容的语义类型。决定结果页展示哪些操作。
enum ScanContentType: String, Codable, CaseIterable, Identifiable {
    case url
    case text
    case wifi
    case email
    case phone
    case sms
    case contact
    case location
    case barcode
    /// iCalendar 事件（`BEGIN:VCALENDAR` / `BEGIN:VEVENT`）。活动海报、会议邀请常见。
    case event
    /// EPC / SEPA 付款码（首行 `BCD`）。欧洲账单上印的那种。
    case payment
    /// 加密货币支付 URI（`bitcoin:` / `ethereum:` 等）。
    case crypto

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .url: return L10n.ResultType.url
        case .text: return L10n.ResultType.text
        case .wifi: return L10n.ResultType.wifi
        case .email: return L10n.ResultType.email
        case .phone: return L10n.ResultType.phone
        case .sms: return L10n.ResultType.sms
        case .contact: return L10n.ResultType.contact
        case .location: return L10n.ResultType.location
        case .barcode: return L10n.ResultType.barcode
        case .event: return L10n.ResultType.event
        case .payment: return L10n.ResultType.payment
        case .crypto: return L10n.ResultType.crypto
        }
    }

    var icon: String {
        switch self {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .wifi: return "wifi"
        case .email: return "envelope"
        case .phone: return "phone"
        case .sms: return "message"
        case .contact: return "person.crop.rectangle"
        case .location: return "mappin.and.ellipse"
        case .barcode: return "barcode"
        case .event: return "calendar"
        case .payment: return "eurosign.circle"
        case .crypto: return "bitcoinsign.circle"
        }
    }

    /// 轻量类型推断。
    /// 只用于决定 UI 展示方式，不作为安全判定依据——不得把格式校验宣传为恶意网址检测。
    static func detect(rawValue: String, isBarcode: Bool) -> ScanContentType {
        if isBarcode { return .barcode }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = value.lowercased()

        if lowercased.hasPrefix("wifi:") { return .wifi }
        if lowercased.hasPrefix("mailto:") { return .email }
        // MATMSG 是 2000 年代的邮件码格式，老营销物料还在用；
        // 归到 email 后由 `externalAction` 转成 mailto，不用单独一套 UI。
        if lowercased.hasPrefix("matmsg:") { return .email }
        if lowercased.hasPrefix("tel:") { return .phone }
        if lowercased.hasPrefix("smsto:") || lowercased.hasPrefix("sms:") { return .sms }
        if lowercased.hasPrefix("begin:vcard") || lowercased.hasPrefix("mecard:") { return .contact }
        if lowercased.hasPrefix("begin:vcalendar") || lowercased.hasPrefix("begin:vevent") { return .event }
        if lowercased.hasPrefix("geo:") { return .location }
        // 纯邮箱地址（`nome@dominio.pt`）必须挡在下面的裸域名分支之前：
        // 否则会被当成「网站」，把 @ 前面的部分当 userinfo，打开 https://dominio.pt。
        if isBareEmailAddress(value) { return .email }
        if isCryptoURI(lowercased) { return .crypto }
        if isEPCPayment(value) { return .payment }
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") { return .url }

        // 裸域名（如 exemplo.pt/loja）也按网址处理，避免只能复制不能打开。
        // 但 "1.2.3"、"v2.0.1" 这类纯数字点分不能当成网址：补上 https:// 会白开一个空白页。
        if !value.contains(" "),
           value.contains("."),
           let candidate = URL(string: "https://\(value)"),
           let host = candidate.host,
           host.contains("."),
           let tld = host.split(separator: ".").last,
           tld.count >= 2,
           tld.allSatisfy(\.isLetter) {
            return .url
        }

        return .text
    }

    /// 加密货币支付 URI：`bitcoin:<地址>?amount=0.001`。
    /// 只认已知币种 scheme，避免把任意 `xxx:` 文本误判成支付码。
    private static func isCryptoURI(_ lowercased: String) -> Bool {
        let schemes = [
            "bitcoin", "bitcoincash", "ethereum", "litecoin",
            "dogecoin", "monero", "ripple", "dash", "solana", "tron"
        ]
        return schemes.contains { lowercased.hasPrefix("\($0):") }
    }

    /// EPC / SEPA 付款码：首行固定 `BCD`，第二行是三位版本号（001/002）。
    /// 不能只判 `BCD` 前缀——那样任何以 BCD 开头的普通文本都会被当成付款码。
    private static func isEPCPayment(_ value: String) -> Bool {
        let lines = value.components(separatedBy: .newlines)
        guard lines.count >= 2,
              lines[0].trimmingCharacters(in: .whitespaces) == "BCD" else { return false }
        let version = lines[1].trimmingCharacters(in: .whitespaces)
        return version.count == 3 && version.allSatisfy(\.isNumber)
    }
}
