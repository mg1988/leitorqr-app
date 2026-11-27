import Foundation

/// 结果页上「跳出 App 处理」的动作。只承载系统内置 scheme，避免任意 URL 注入。
struct ScanExternalAction {
    let url: URL
    let title: String
    let symbol: String
}

/// 一次扫描/识别得到的、用于 UI 展示与后续操作的内容（未持久化）。
struct ScanContent: Identifiable, Hashable {
    let id: UUID
    let rawValue: String
    let type: ScanContentType
    let barcodeFormat: BarcodeFormat?
    let source: ScanSource

    init(
        id: UUID = UUID(),
        rawValue: String,
        barcodeFormat: BarcodeFormat? = nil,
        source: ScanSource = .camera
    ) {
        self.init(id: id, rawValue: rawValue, type: nil, barcodeFormat: barcodeFormat, source: source)
    }

    /// 历史详情用：类型以入库时的判断为准，不随 `detect` 规则调整而漂移。
    init(
        id: UUID = UUID(),
        rawValue: String,
        type: ScanContentType?,
        barcodeFormat: BarcodeFormat? = nil,
        source: ScanSource = .camera
    ) {
        self.id = id
        self.rawValue = rawValue
        self.barcodeFormat = barcodeFormat
        self.source = source
        // QR 里装的也可能是纯数字，此时仍按文本/网址语义处理；只有真正的条形码才标记为 barcode。
        let isBarcode = (barcodeFormat?.isTwoDimensional == false)
        self.type = type ?? ScanContentType.detect(rawValue: rawValue, isBarcode: isBarcode)
    }

    /// 只有 http/https 才提供打开操作。
    var openableURL: URL? {
        guard type == .url else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           url.host != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    /// 展示用域名（只去掉开头的 www.，不误伤子域里的 www.）。
    var displayHost: String? {
        guard let host = openableURL?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// 电话 / 邮件 / 短信 / 地图：交给系统 App 处理，比只给一段文本有用得多。
    /// 只接受本类型对应的 scheme，且必须 canOpenURL，绝不把原始负载整个丢给 open。
    ///
    /// 联系人 / 日历 / EPC 付款 / 加密支付**刻意不在这里**：
    /// 它们要写通讯录、写日历、或导出一笔转账，全部走结果页的结构化卡片
    /// 让用户先看清内容再点按钮，而不是一个笼统的「打开」。
    var externalAction: ScanExternalAction? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .phone:
            guard let url = URL(string: trimmed), url.scheme?.lowercased() == "tel" else { return nil }
            return ScanExternalAction(url: url, title: L10n.Result.call, symbol: "phone")
        case .email:
            guard let url = mailActionURL(from: trimmed) else { return nil }
            return ScanExternalAction(url: url, title: L10n.Result.sendEmail, symbol: "envelope")
        case .sms:
            guard let url = smsActionURL(from: trimmed) else { return nil }
            return ScanExternalAction(url: url, title: L10n.Result.sendSMS, symbol: "message")
        case .location:
            guard let url = mapActionURL(from: trimmed) else { return nil }
            return ScanExternalAction(url: url, title: L10n.Result.openInMaps, symbol: "map")
        case .url, .text, .wifi, .contact, .event, .payment, .crypto, .barcode:
            return nil
        }
    }

    /// `MATMSG:TO:a@b.pt;SUB:Olá;BODY:Corpo;;` 是打印在名片/海报上的老格式，
    /// 系统 Mail **不认** `matmsg:` scheme，必须自己拼成 `mailto:`。
    /// 裸邮箱地址（`nome@dominio.pt`）同理，也得补上 scheme 才能交给 Mail。
    private func mailActionURL(from value: String) -> URL? {
        let lower = value.lowercased()
        if lower.hasPrefix("mailto:") {
            // 原生格式原样保留（可能已带 ?subject= / ?cc=）。
            return URL(string: value).flatMap {
                $0.scheme?.lowercased() == "mailto" ? $0 : nil
            }
        }
        return MailMessage.parse(value)?.mailtoURL
    }

    /// `SMSTO:<号>:<正文>` 是创建页用的格式，系统不认；转成 `sms:<号>&body=<转义正文>`。
    /// `sms:` 原生格式原样保留（可能已带 `?body=` / `&body=`）。
    private func smsActionURL(from value: String) -> URL? {
        if value.lowercased().hasPrefix("smsto:") {
            let rest = String(value.dropFirst("SMSTO:".count))
            guard let separator = rest.firstIndex(of: ":") else { return nil }
            let number = String(rest[..<separator])
            let body = String(rest[rest.index(after: separator)...])
            // 号码与正文都是二维码内容，攻击者可控：`.urlQueryAllowed` 不转义
            // `? & = +`，号码里混进分隔符就能覆盖/伪造 body 参数。
            // 号码只放行电话字符，正文按 query 值严格编码。
            guard !number.isEmpty,
                  let encodedNumber = number.addingPercentEncoding(withAllowedCharacters: Self.phoneNumberAllowed),
                  let encodedBody = body.addingPercentEncoding(withAllowedCharacters: Self.smsQueryValueAllowed) else {
                return nil
            }
            return URL(string: "sms:\(encodedNumber)&body=\(encodedBody)")
        }
        guard let url = URL(string: value), url.scheme?.lowercased() == "sms" else { return nil }
        return url
    }

    /// 电话号码字符集：数字与 `+ * # - ( )`（短代码、分机、E.164 都覆盖）。
    private static let phoneNumberAllowed = CharacterSet(charactersIn: "+*#-()0123456789")
    /// query 值专用：`.urlQueryAllowed` 会放行 `? & = +` 这些分隔符本身，必须排除。
    private static let smsQueryValueAllowed = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "?&=+"))

    /// `geo:lat,long` 转成 Apple Maps 的网页入口。
    ///
    /// **iOS 的 Maps 不接管 `geo:` scheme**（实测 `simctl openurl geo:38.7,-9.1`
    /// 直接报 LSApplicationWorkspaceError 115），原样丢给 `open` 一定失败，
    /// 结果页的「在地图中打开」形同虚设。`maps.apple.com` 才是 iOS 认可的入口。
    /// 必须校验出数字坐标，防止 `geo:javascript:...` 这类被塞进地图。
    private func mapActionURL(from value: String) -> URL? {
        guard value.lowercased().hasPrefix("geo:") else { return nil }
        let coordinate = String(value.dropFirst("geo:".count))
            .split(separator: ",", maxSplits: 1).map(String.init)
        guard coordinate.count == 2,
              Double(coordinate[0]) != nil, Double(coordinate[1]) != nil else { return nil }
        let lat = coordinate[0].trimmingCharacters(in: .whitespaces)
        let lng = coordinate[1].trimmingCharacters(in: .whitespaces)
        return URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)")
    }

    /// 历史列表里的一行摘要。
    var summary: String {
        rawValue.components(separatedBy: .newlines).joined(separator: " ")
    }

    /// 给人看的一句话摘要。
    ///
    /// `WIFI:T:WPA;S:Casa;P:segredo123;;` 这种负载原样摊在列表里等于没写，
    /// 用户要的是"这是哪个网"。结构化负载只取最有辨识度的那一段。
    var readableSummary: String {
        let flat = summary
        switch type {
        case .wifi:
            return fieldValue(in: rawValue, key: "S") ?? flat
        case .contact:
            return ContactCard.parse(rawValue)?.name ?? flat
        case .event:
            return CalendarEvent.parse(rawValue)?.summary ?? flat
        case .payment:
            guard let payment = SEPAPayment.parse(rawValue) else { return flat }
            let recipient = payment.recipient.isEmpty ? payment.iban : payment.recipient
            let amount = payment.displayAmount
            return amount.isEmpty ? recipient : "\(recipient) · \(amount)"
        case .crypto:
            guard let crypto = CryptoPayment.parse(rawValue) else { return flat }
            return "\(crypto.currencyName) · \(crypto.shortAddress)"
        case .email:
            let stripped = strippingMailPrefixes(flat)
            return stripped.isEmpty ? flat : stripped
        case .phone:
            return flat.replacingOccurrences(of: "tel:", with: "", options: .caseInsensitive)
        case .sms:
            var body = flat
            for prefix in ["SMSTO:", "sms:"] where body.lowercased().hasPrefix(prefix.lowercased()) {
                body = String(body.dropFirst(prefix.count))
                break
            }
            // 只切第一个冒号：正文里的 "10:30"、URL 里的 "://" 都得原样留着。
            guard let separator = body.firstIndex(of: ":") else { return body }
            let number = String(body[..<separator])
            let text = String(body[body.index(after: separator)...])
            return text.isEmpty ? number : "\(number) · \(text)"
        case .location:
            return flat.replacingOccurrences(of: "geo:", with: "", options: .caseInsensitive)
        case .url, .text, .barcode:
            return flat
        }
    }

    /// `mailto:` / `MATMSG:TO:` 的外壳对用户没有意义，剥掉只留地址。
    private func strippingMailPrefixes(_ value: String) -> String {
        let lower = value.lowercased()
        if lower.hasPrefix("mailto:") {
            let rest = String(value.dropFirst("mailto:".count))
            return rest.split(separator: "?").first.map(String.init) ?? rest
        }
        if lower.hasPrefix("matmsg:") {
            return fieldValue(in: value, key: "TO") ?? ""
        }
        return value
    }

    /// 从 `KEY:value;` 形式的负载里取一段。
    /// vCard / MECARD 常用 CRLF，分隔符必须同时含 `\r`；`WIFI:` / `MECARD:` 外壳要先剥掉。
    private func fieldValue(in payload: String, key: String) -> String? {
        let prefix = key.uppercased() + ":"
        for raw in payload.components(separatedBy: CharacterSet(charactersIn: ";\r\n")) {
            var component = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            for shell in ["WIFI:", "MECARD:"] where component.uppercased().hasPrefix(shell) {
                component = String(component.dropFirst(shell.count))
                break
            }
            if component.uppercased().hasPrefix(prefix) {
                let value = String(component.dropFirst(prefix.count))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
