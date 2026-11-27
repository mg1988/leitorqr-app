import Foundation

// 结构化负载解析：vCard / MECARD、iCalendar、EPC 付款码、加密支付 URI、邮件码。
//
// 都在端侧完成，不联网、不依赖第三方库。解析失败一律返回 nil，
// 由 UI 回退成「原始文本」展示——宁可少显示，不要瞎猜。

// MARK: - 公共工具

/// `KEY:value;KEY:value;;` 形式的负载解析（MECARD、MATMSG 同源）。
///
/// 规则只有一条：**每个字段里第一个冒号**是键值分隔符，之后出现的冒号属于值——
/// 邮件正文里的「Re: 报价」、SSID 里的冒号都得原样留着。
/// `\;` 是转义的分号，`\\` 是转义的反斜杠。
enum SemicolonFields {
    static func parse(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var value = ""
        var readingValue = false
        var escaped = false

        for character in body {
            if escaped {
                value.append(character)
                escaped = false
                continue
            }
            switch character {
            case "\\":
                escaped = true
            case ";":
                if !key.isEmpty { result[key.uppercased()] = value }
                key = ""
                value = ""
                readingValue = false
            case ":" where !readingValue:
                readingValue = true
            default:
                if readingValue { value.append(character) } else { key.append(character) }
            }
        }
        if !key.isEmpty { result[key.uppercased()] = value }
        return result
    }
}

/// 裸邮箱地址：`nome@dominio.pt`。
///
/// 只接受「两段、域名有点、没有路径和协议前缀」这种最保守的形态，
/// 宁可有几个漏判，也不能把带 @ 的网址误判成邮箱。
func isBareEmailAddress(_ value: String) -> Bool {
    guard !value.contains(" "),
          !value.contains("/"),
          !value.contains(":"),
          !value.contains("?") else { return false }
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty else { return false }
    let domain = parts[1]
    guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }
    return domain.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
}

/// 按 RFC 6350 / RFC 5545 的行折叠（line folding）展开：
/// 续行以**一个空格或 TAB 开头**，要和上一行直接拼接。
///
/// 不展开的话，长值（`ORG`、`DESCRIPTION`、base64 的 `PHOTO`）会被截断成
/// 半句话，甚至把 base64 片段当成字段名。
func unfoldedLines(_ text: String) -> [String] {
    var lines: [String] = []
    for raw in text.components(separatedBy: .newlines) {
        if let first = raw.first, first == " " || first == "\t", !lines.isEmpty {
            lines[lines.count - 1] += raw.dropFirst()
        } else {
            lines.append(raw)
        }
    }
    return lines
}

/// 把「姓 + 名」拼回一个可读姓名。
///
/// 顺序**按名字本身的书写体系**判断，而不是按界面语言：
/// - 中日韩姓名是「姓 名」且不加空格（`张` + `三` → 张三，`山田` + `太郎` → 山田太郎）；
/// - 其余（拉丁、西里尔、阿拉伯…）是「名 姓」（`Silva` + `João` → João Silva）。
///
/// 试过 `PersonNameComponentsFormatter` + 当前 locale：它会把中文界面下的
/// 葡语联系人排成「Silva João」，把葡语界面下的中文名排成「三 张」，两个方向都错。
/// 名字要不要倒装是姓名自己的属性，跟看的人用什么语言无关。
func personName(family: String, given: String) -> String {
    let family = family.trimmingCharacters(in: .whitespaces)
    let given = given.trimmingCharacters(in: .whitespaces)
    guard !family.isEmpty || !given.isEmpty else { return "" }

    if isCJKName(family) || isCJKName(given) {
        return family + given
    }
    return [given, family].filter { !$0.isEmpty }.joined(separator: " ")
}

/// 汉字 / 日文假名 / 韩文谚文。只要有一侧是这些文字，就按「姓在前」处理。
private func isCJKName(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x3040...0x30FF,   // 平假名 + 片假名
             0x3400...0x4DBF,   // 汉字扩展 A
             0x4E00...0x9FFF,   // 汉字基本区
             0xAC00...0xD7AF,   // 谚文音节
             0xF900...0xFAFF:   // 兼容汉字
            return true
        default:
            return false
        }
    }
}

// MARK: - 联系人

/// 从 vCard 3.0 或 MECARD 里抽出结果页要显示的几行。
/// 不追求完整映射（地址、生日等），够用户确认「这是谁」即可。
struct ContactCard {
    let name: String
    let phone: String
    let email: String
    let organization: String

    var isEmpty: Bool {
        name.isEmpty && phone.isEmpty && email.isEmpty && organization.isEmpty
    }

    static func parse(_ payload: String) -> ContactCard? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()

        if upper.hasPrefix("MECARD:") {
            let fields = SemicolonFields.parse(String(trimmed.dropFirst("MECARD:".count)))
            let card = ContactCard(
                name: mecName(fields["N"] ?? ""),
                phone: fields["TEL"] ?? "",
                email: fields["EMAIL"] ?? "",
                organization: fields["ORG"] ?? ""
            )
            return card.isEmpty ? nil : card
        }

        if upper.hasPrefix("BEGIN:VCARD") {
            return parseVCard(trimmed)
        }
        return nil
    }

    /// MECARD 的 `N` 是 `Sobrenome,Nome`（**逗号**，和 vCard 的分号相反）。
    /// 原样显示会变成「Silva,João」——姓在前、还带个逗号，中文名会变成「张,三」。
    private static func mecName(_ value: String) -> String {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return parts.first ?? "" }
        return personName(family: parts[0], given: parts[1])
    }

    private static func parseVCard(_ text: String) -> ContactCard? {
        var name = ""
        var structured = ""
        var phone = ""
        var email = ""
        var organization = ""

        for rawLine in unfoldedLines(text) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // 带参数的行如 `TEL;TYPE=CELL:+351...`：只取冒号前最后一段的键名。
            guard let colon = line.firstIndex(of: ":") else { continue }
            let left = String(line[..<colon])
            let value = String(line[line.index(after: colon)...])
            let key = left.split(separator: ";").first.map(String.init)?.uppercased() ?? ""

            switch key {
            case "FN":
                if name.isEmpty { name = unescape(value) }
            case "N":
                // `Sobrenome;Nome;;;`，按语言拼回「Nome Sobrenome」/「张三」。
                let parts = value.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
                let family = parts.first ?? ""
                let given = parts.count > 1 ? parts[1] : ""
                let combined = personName(family: family, given: given)
                if !combined.isEmpty { structured = unescape(combined) }
            case "TEL":
                if phone.isEmpty { phone = unescape(value) }
            case "EMAIL":
                if email.isEmpty { email = unescape(value) }
            case "ORG":
                if organization.isEmpty { organization = unescape(value) }
            default:
                break
            }
        }

        let card = ContactCard(
            name: name.isEmpty ? structured : name,
            phone: phone,
            email: email,
            organization: organization
        )
        return card.isEmpty ? nil : card
    }

    /// vCard 里的 `\,` `\;` `\n`。
    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 日历事件

struct CalendarEvent {
    let summary: String
    let start: Date?
    let end: Date?
    let location: String
    let notes: String

    static func parse(_ payload: String) -> CalendarEvent? {
        guard payload.uppercased().contains("BEGIN:VEVENT") else { return nil }

        var summary = ""
        var start: Date?
        var end: Date?
        var location = ""
        var notes = ""

        for rawLine in unfoldedLines(payload) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let left = String(line[..<colon])
            let value = String(line[line.index(after: colon)...])
            // `DTSTART;TZID=Europe/Lisbon:20261120T100000`
            let key = left.split(separator: ";").first.map(String.init)?.uppercased() ?? ""

            switch key {
            case "SUMMARY":
                if summary.isEmpty { summary = unescape(value) }
            case "DTSTART":
                if start == nil { start = parseDate(value, parameters: left) }
            case "DTEND":
                if end == nil { end = parseDate(value, parameters: left) }
            case "LOCATION":
                if location.isEmpty { location = unescape(value) }
            case "DESCRIPTION":
                if notes.isEmpty { notes = unescape(value) }
            default:
                break
            }
        }

        // 标题和开始时间都拿不到，就没有「加到日历」的意义。
        guard !summary.isEmpty || start != nil else { return nil }

        // 脏数据里 DTEND 可能早于 DTSTART（时区写错、手改过、只有 DATE 没有时间）。
        // 原样交给 EventKit 会得到零长度甚至负长度的日程，直接丢掉这个结束时间更稳妥。
        var validEnd = end
        if let s = start, let e = end, e <= s { validEnd = nil }

        return CalendarEvent(
            summary: summary.isEmpty ? L10n.ResultType.event : summary,
            start: start,
            end: validEnd,
            location: location,
            notes: notes
        )
    }

    /// iCalendar 的三种时间形态：UTC（`…Z`）、带时区（`TZID=`）、本地（无后缀）、全天（只有日期）。
    ///
    /// **不能靠「依次试格式」来判断**：`DateFormatter` 对缺失的 `Z` 是宽容的，
    /// `yyyyMMdd'T'HHmmss'Z'` 会照样匹配 `20261120T200000` 并当成 UTC，
    /// 于是 UTC+8 的机器上 20:00 的会议变成次日 04:00。必须先看输入再选格式。
    private static func parseDate(_ raw: String, parameters: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false

        let zone = timeZone(from: parameters)
        if value.hasSuffix("Z") {
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else if value.contains("T") {
            formatter.timeZone = zone ?? .current
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        } else {
            formatter.timeZone = zone ?? .current
            formatter.dateFormat = "yyyyMMdd"
        }
        return formatter.date(from: value)
    }

    /// 从 `DTSTART;TZID=Europe/Lisbon` 这样的参数段里取时区。
    private static func timeZone(from parameters: String) -> TimeZone? {
        for part in parameters.split(separator: ";").dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2, pair[0].uppercased() == "TZID" else { continue }
            // 时区名里可能带双引号（`TZID="Europe/Lisbon"`）。
            let identifier = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return TimeZone(identifier: identifier)
        }
        return nil
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - EPC / SEPA 付款码

/// 欧洲账单上印的付款码。字段按行固定顺序，空字段留空行。
struct SEPAPayment {
    let recipient: String
    let iban: String
    let bic: String
    let amount: String
    let reference: String

    static func parse(_ payload: String) -> SEPAPayment? {
        let lines = payload.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 7,
              lines[0] == "BCD",
              lines[1].count == 3,
              lines[1].allSatisfy(\.isNumber) else { return nil }

        // 索引：0 BCD / 1 版本 / 2 字符集 / 3 标识 / 4 BIC / 5 收款人 / 6 IBAN
        //       7 金额 / 8 用途代码 / 9 参考 / 10 说明
        func value(_ index: Int) -> String {
            index < lines.count ? lines[index] : ""
        }

        let iban = value(6).replacingOccurrences(of: " ", with: "")
        guard !iban.isEmpty else { return nil }

        return SEPAPayment(
            recipient: value(5),
            iban: value(6),
            bic: value(4),
            amount: value(7),
            reference: value(9).isEmpty ? value(10) : value(9)
        )
    }

    /// EPC 的金额带币种前缀（`EUR12.50`）。按当前 App 语言排成 `12,50 €` / `€12.50`，
    /// 比原样吐一串字符更像个金额。解析不出来就老实回退原值。
    var displayAmount: String {
        guard !amount.isEmpty else { return "" }
        let digits = amount.uppercased().hasPrefix("EUR")
            ? String(amount.dropFirst(3))
            : amount
        guard let value = Double(digits.replacingOccurrences(of: ",", with: ".")) else { return amount }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = LanguageManager.shared.locale
        return formatter.string(from: NSNumber(value: value)) ?? amount
    }
}

// MARK: - 邮件码（MATMSG / mailto 带参数）

/// 邮件码：`MATMSG:TO:a@b;SUB:x;BODY:y;;`，以及带 `?subject=&body=` 的 `mailto:`。
/// 两者都是「一段协议串」，直接摊在结果页上等于乱码，拆成三行才有用。
struct MailMessage {
    let recipient: String
    let subject: String
    let body: String

    static func parse(_ payload: String) -> MailMessage? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.hasPrefix("matmsg:") {
            let fields = SemicolonFields.parse(String(trimmed.dropFirst("MATMSG:".count)))
            let recipient = fields["TO"] ?? ""
            guard !recipient.isEmpty else { return nil }
            return MailMessage(recipient: recipient,
                               subject: fields["SUB"] ?? "",
                               body: fields["BODY"] ?? "")
        }

        if lower.hasPrefix("mailto:") {
            let rest = String(trimmed.dropFirst("mailto:".count))
            let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            let recipient = String(parts[0])
            guard !recipient.isEmpty else { return nil }

            var subject = ""
            var body = ""
            if parts.count == 2 {
                for pair in parts[1].split(separator: "&") {
                    let item = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    guard item.count == 2 else { continue }
                    let value = item[1].removingPercentEncoding ?? item[1]
                    switch item[0].lowercased() {
                    case "subject": subject = value
                    case "body": body = value
                    default: break
                    }
                }
            }
            return MailMessage(recipient: recipient, subject: subject, body: body)
        }

        // 裸邮箱地址（`nome@dominio.pt`）：没有协议前缀，但语义上一个字都不缺。
        if isBareEmailAddress(trimmed) {
            return MailMessage(recipient: trimmed, subject: "", body: "")
        }

        return nil
    }

    /// 交给系统 Mail 的 URL。MATMSG 系统不认，必须换成 `mailto:`。
    ///
    /// 字段全部来自二维码，攻击者可控：不能用 `.urlQueryAllowed` 手工拼接
    /// （它不转义 `? & = +`，能往 query 里注入额外的 bcc/覆盖 subject），
    /// 必须走 `URLComponents`，由它负责把分隔符和非法字符编码掉。
    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        var queryItems: [URLQueryItem] = []
        if !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }
}

// MARK: - 加密支付 URI

struct CryptoPayment {
    let currency: String
    let address: String
    let amount: String
    let rawURI: String

    static func parse(_ payload: String) -> CryptoPayment? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let scheme = String(trimmed[..<colon]).lowercased()
        let known = [
            "bitcoin", "bitcoincash", "ethereum", "litecoin",
            "dogecoin", "monero", "ripple", "dash", "solana", "tron"
        ]
        guard known.contains(scheme) else { return nil }

        let rest = String(trimmed[trimmed.index(after: colon)...])
        var addressPart = rest
        var query = ""
        if let question = rest.firstIndex(of: "?") {
            addressPart = String(rest[..<question])
            query = String(rest[rest.index(after: question)...])
        }
        // `bitcoin://addr` 这种带双斜杠的写法也要能剥掉。
        while addressPart.hasPrefix("/") { addressPart.removeFirst() }
        guard !addressPart.isEmpty else { return nil }

        var amount = ""
        for pair in query.split(separator: "&") {
            let item = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if item.count == 2, item[0].lowercased() == "amount" {
                amount = item[1]
            }
        }

        return CryptoPayment(
            currency: scheme,
            address: addressPart,
            amount: amount,
            rawURI: trimmed
        )
    }

    /// 地址动辄 34–42 字符，列表里只留头尾便于核对，完整值仍在卡片里可复制。
    var shortAddress: String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    /// 交给钱包 App 的 URI：剥掉 `r=` 与 `req-*` 参数。
    /// `r=`（BIP70/72）会让钱包去拉一个攻击者可控的支付请求 URL；
    /// BIP21 规定不理解 `req-*` 参数的客户端应当拒绝整个 URI——剥掉即视为不支持。
    /// 金额等常规参数原样保留，钱包看到的与结果卡片展示的一致。
    var openURI: URL? {
        guard let colon = rawURI.firstIndex(of: ":") else { return nil }
        let scheme = String(rawURI[..<colon]).lowercased()
        let rest = String(rawURI[rawURI.index(after: colon)...])
        var addressPart = rest
        var query = ""
        if let question = rest.firstIndex(of: "?") {
            addressPart = String(rest[..<question])
            query = String(rest[rest.index(after: question)...])
        }
        let safePairs = query.split(separator: "&").filter { pair in
            let key = pair.split(separator: "=", maxSplits: 1).first?.lowercased() ?? ""
            return key != "r" && !key.hasPrefix("req-")
        }
        var value = "\(scheme):\(addressPart)"
        if !safePairs.isEmpty { value += "?" + safePairs.joined(separator: "&") }
        return URL(string: value)
    }

    /// `capitalized` 会把 `bitcoincash` 写成「Bitcoincash」，这些是固定写法。
    var currencyName: String {
        switch currency {
        case "bitcoin": return "Bitcoin"
        case "bitcoincash": return "Bitcoin Cash"
        case "ethereum": return "Ethereum"
        case "litecoin": return "Litecoin"
        case "dogecoin": return "Dogecoin"
        case "monero": return "Monero"
        case "ripple": return "XRP"
        case "dash": return "Dash"
        case "solana": return "Solana"
        case "tron": return "TRON"
        default: return currency.capitalized
        }
    }
}
