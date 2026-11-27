import SwiftUI

/// 二维码的创建类型。
///
/// 分成两组：社交平台（本质都是"用户名 → 主页链接"）与内容类型
/// （网址、纯文本、Wi-Fi、联系人）。分组决定首页的网格分区，
/// 也决定表单长什么样——社交平台共用一个输入框，其余各有一套字段。
enum CreateType: String, CaseIterable, Identifiable, Hashable {

    // 社交平台
    case instagram
    case tiktok
    case youtube
    case facebook
    case whatsapp
    case telegram
    case linkedin
    case x
    case wechat
    case xiaohongshu

    // 内容类型
    case website
    case text
    case email
    case sms
    case phone
    case wifi
    case contact
    case location

    var id: String { rawValue }

    static var social: [CreateType] {
        [.instagram, .tiktok, .youtube, .facebook, .whatsapp,
         .telegram, .linkedin, .x, .wechat, .xiaohongshu]
    }

    static var others: [CreateType] {
        [.website, .text, .email, .sms, .phone, .wifi, .contact, .location]
    }

    var isSocial: Bool { Self.social.contains(self) }

    // MARK: - 文案

    var title: String {
        switch self {
        case .instagram: return L10n.Create.typeInstagram
        case .tiktok: return L10n.Create.typeTikTok
        case .youtube: return L10n.Create.typeYouTube
        case .facebook: return L10n.Create.typeFacebook
        case .whatsapp: return L10n.Create.typeWhatsApp
        case .telegram: return L10n.Create.typeTelegram
        case .linkedin: return L10n.Create.typeLinkedIn
        case .x: return L10n.Create.typeX
        case .wechat: return L10n.Create.typeWeChat
        case .xiaohongshu: return L10n.Create.typeXiaohongshu
        case .website: return L10n.Create.typeWebsite
        case .text: return L10n.Create.typeText
        case .email: return L10n.Create.typeEmail
        case .sms: return L10n.Create.typeSMS
        case .phone: return L10n.Create.typePhone
        case .wifi: return L10n.Create.typeWiFi
        case .contact: return L10n.Create.typeContact
        case .location: return L10n.Create.typeLocation
        }
    }

    // MARK: - 视觉

    /// 非品牌类型用的系统图标（品牌类型自己画，见 `BrandMark`）。
    var symbolName: String {
        switch self {
        case .website: return "globe"
        case .text: return "text.alignleft"
        case .email: return "envelope"
        case .sms: return "message"
        case .phone: return "phone"
        case .wifi: return "wifi"
        case .contact: return "person.crop.circle"
        case .location: return "location"
        default: return "qrcode"
        }
    }

    /// 每个类型专属的品牌与功能主色（严格遵循 Apple HIG 色彩规范与高辨识度）
    var tint: Color {
        switch self {
        case .instagram: return Color(light: 0xE1306C, dark: 0xF2608C)
        case .tiktok: return Color(light: 0x111418, dark: 0x2A2E35)
        case .youtube: return Color(light: 0xE62E2E, dark: 0xFF5A5A)
        case .facebook: return Color(light: 0x1877F2, dark: 0x4B96F8)
        case .whatsapp: return Color(light: 0x25D366, dark: 0x3EDC7B)
        case .telegram: return Color(light: 0x229ED9, dark: 0x48BCEE)
        case .linkedin: return Color(light: 0x0A66C2, dark: 0x368CE3)
        case .x: return Color(light: 0x111418, dark: 0x2A2E35)
        case .wechat: return Color(light: 0x07C160, dark: 0x2CD87D)
        case .xiaohongshu: return Color(light: 0xFF2442, dark: 0xFF576F)
        // 内容类型：每一个都有独立色彩系统
        case .website: return Color(light: 0x007AFF, dark: 0x389BFF)
        case .text: return Color(light: 0xFF9500, dark: 0xFFAA33)
        case .email: return Color(light: 0x5856D6, dark: 0x7A79EC)
        case .sms: return Color(light: 0x34C759, dark: 0x4CD964)
        case .phone: return Color(light: 0x30B0C7, dark: 0x4ED2E6)
        case .wifi: return Color(light: 0xAF52DE, dark: 0xC576EE)
        case .contact: return Color(light: 0xFF2D55, dark: 0xFF5474)
        case .location: return Color(light: 0xFF3B30, dark: 0xFF6259)
        }
    }

    var heroID: String { "type_\(id)" }

    /// 码中心品牌图标方块的颜色（取 `tint` 的浅色值；码图是导出用的，不随深色模式变）。
    var brandHex: UInt32 {
        switch self {
        case .instagram: return 0xE1306C
        case .tiktok: return 0x111418
        case .youtube: return 0xE62E2E
        case .facebook: return 0x1877F2
        case .whatsapp: return 0x25D366
        case .telegram: return 0x229ED9
        case .linkedin: return 0x0A66C2
        case .x: return 0x111418
        case .wechat: return 0x07C160
        case .xiaohongshu: return 0xFF2442
        case .website: return 0x007AFF
        case .text: return 0xFF9500
        case .email: return 0x5856D6
        case .sms: return 0x34C759
        case .phone: return 0x30B0C7
        case .wifi: return 0xAF52DE
        case .contact: return 0xFF2D55
        case .location: return 0xFF3B30
        }
    }
}

// MARK: - 生成内容

extension CreateType {

    /// 把表单填写的内容组装成二维码要承载的字符串。
    /// 返回 nil 表示"还没填够，别急着报错"（如 Wi-Fi 还没填 SSID）。
    func payload(from draft: CreateDraft) throws -> String? {
        switch self {
        case .website:
            let trimmed = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard let url = QRGeneratorService.normalizedURL(from: trimmed) else {
                throw CreateBuildError.invalidURL
            }
            return url.absoluteString

        case .text:
            let trimmed = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed

        case .instagram, .tiktok, .youtube, .facebook, .telegram, .linkedin, .x, .xiaohongshu:
            return try socialProfileURL(handle: draft.primary)?.absoluteString

        case .wechat:
            // 微信没有公开的个人主页链接体系，官方好友码是服务端签发的短链（u.wechat.com/…）。
            // 拿不到就只能二选一：粘贴自己的好友码链接，或者把微信号当文本编码。
            return try wechatPayload(raw: draft.primary)

        case .email:
            let address = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !address.isEmpty else { return nil }
            guard Self.isValidEmail(address) else { throw CreateBuildError.invalidEmail }
            return "mailto:\(address)"

        case .sms:
            // 号码在 primary，短信任体在 secondary。SMSTO 是各平台扫码器都认的老格式
            // （iOS 相机 / Android 相机都能直接唤起信息 App）。
            let digits = draft.primary.filter { $0.isNumber || $0 == "+" }
            guard !digits.isEmpty else { return nil }
            guard digits.filter(\.isNumber).count >= 5 else { throw CreateBuildError.invalidPhone }
            let body = draft.secondary.trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? "SMSTO:\(digits)" : "SMSTO:\(digits):\(body)"

        case .phone:
            let digits = draft.primary.filter { $0.isNumber || $0 == "+" }
            guard !digits.isEmpty else { return nil }
            guard digits.filter(\.isNumber).count >= 5 else { throw CreateBuildError.invalidPhone }
            return "tel:\(digits)"

        case .location:
            let latitude = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            let longitude = draft.secondary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !latitude.isEmpty, !longitude.isEmpty else { return nil }
            guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
                  let lng = Double(longitude.replacingOccurrences(of: ",", with: ".")),
                  (-90...90).contains(lat), (-180...180).contains(lng) else {
                throw CreateBuildError.invalidCoordinates
            }
            return String(format: "geo:%.6f,%.6f", lat, lng)

        case .whatsapp:
            let digits = draft.primary.filter(\.isNumber)
            guard !digits.isEmpty else { return nil }
            guard digits.count >= 8 else { throw CreateBuildError.invalidPhone }
            return "https://wa.me/\(digits)"

        case .wifi:
            let ssid = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ssid.isEmpty else { return nil }
            var fields = ["T:\(draft.wifiSecurity.token)", "S:\(Self.escapeWiFi(ssid))"]
            if draft.wifiSecurity != .none, !draft.password.isEmpty {
                fields.append("P:\(Self.escapeWiFi(draft.password))")
            }
            if draft.wifiHidden {
                fields.append("H:true")
            }
            return "WIFI:\(fields.joined(separator: ";"));;"

        case .contact:
            return Self.vCard(from: draft)
        }
    }

    /// 社交平台：允许直接填用户名，也允许整条主页链接原样粘进来。
    private func socialProfileURL(handle raw: String) throws -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("://") || trimmed.lowercased().hasPrefix("www.") {
            guard let url = QRGeneratorService.normalizedURL(from: trimmed) else {
                throw CreateBuildError.invalidURL
            }
            return url
        }

        var name = trimmed
        if name.hasPrefix("@") { name.removeFirst() }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !name.isEmpty else { return nil }
        guard !name.contains(" ") else { throw CreateBuildError.invalidHandle }

        let prefix: String
        switch self {
        case .instagram: prefix = "https://instagram.com/"
        case .tiktok: prefix = "https://tiktok.com/@"
        case .youtube: prefix = "https://youtube.com/@"
        case .facebook: prefix = "https://facebook.com/"
        case .telegram: prefix = "https://t.me/"
        case .linkedin: prefix = "https://linkedin.com/in/"
        case .x: prefix = "https://x.com/"
        case .xiaohongshu: prefix = "https://www.xiaohongshu.com/user/profile/"
        default: return nil
        }
        return URL(string: prefix + name)
    }

    private func wechatPayload(raw: String) throws -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") || trimmed.lowercased().hasPrefix("www.") {
            guard let url = QRGeneratorService.normalizedURL(from: trimmed) else {
                throw CreateBuildError.invalidURL
            }
            return url.absoluteString
        }
        var identifier = trimmed
        if identifier.hasPrefix("@") { identifier.removeFirst() }
        guard !identifier.isEmpty, !identifier.contains(" ") else {
            throw CreateBuildError.invalidHandle
        }
        // 没有可用链接时退化成文本：扫出来能看到微信号，便于手动搜索添加。
        return identifier
    }

    private static func isValidEmail(_ address: String) -> Bool {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
            && !address.contains(" ")
    }

    /// Wi-Fi 规范要求转义这几个字符，否则扫描端会把参数切断。
    private static func escapeWiFi(_ value: String) -> String {
        var escaped = ""
        for character in value {
            if "\\;,:\"".contains(character) {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }

    /// vCard 3.0。iOS / Android 相机扫到都会直接弹"添加联系人"。
    private static func vCard(from draft: CreateDraft) -> String? {
        let name = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = draft.secondary.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.tertiary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !phone.isEmpty else { return nil }

        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        let safeName = escapeVCard(name)
        lines.append("N:\(safeName);;;;")
        if !safeName.isEmpty {
            lines.append("FN:\(safeName)")
        }
        if !phone.isEmpty {
            lines.append("TEL;TYPE=CELL:\(escapeVCard(phone))")
        }
        if !email.isEmpty {
            lines.append("EMAIL:\(escapeVCard(email))")
        }
        if !draft.quaternary.isEmpty {
            lines.append("ORG:\(escapeVCard(draft.quaternary))")
        }
        lines.append("END:VCARD")
        return lines.joined(separator: "\n")
    }

    private static func escapeVCard(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

/// 表单里填写的内容。字段名按"主 / 次"顺序排列，
/// 各类型只用到其中一部分（见 `CreateType.payload(from:)`）。
struct CreateDraft: Equatable {
    var primary = ""
    var secondary = ""
    var tertiary = ""
    var quaternary = ""
    var password = ""
    var wifiSecurity: WiFiSecurity = .wpa
    var wifiHidden = false

    var isEmpty: Bool {
        primary.isEmpty && secondary.isEmpty
    }
}

enum WiFiSecurity: String, CaseIterable, Identifiable {
    case wpa
    case wep
    case none

    var id: String { rawValue }

    /// Wi-Fi 二维码里的 T 字段取值。
    var token: String {
        switch self {
        case .wpa: return "WPA"
        case .wep: return "WEP"
        case .none: return "nopass"
        }
    }

    var title: String {
        switch self {
        case .wpa: return L10n.Create.wifiSecurityWPA
        case .wep: return L10n.Create.wifiSecurityWEP
        case .none: return L10n.Create.wifiSecurityNone
        }
    }
}

enum CreateBuildError: LocalizedError, Equatable {
    case invalidURL
    case invalidHandle
    case invalidPhone
    case invalidEmail
    case invalidCoordinates

    var errorDescription: String? {
        switch self {
        case .invalidURL: return L10n.Create.errorInvalidURL
        case .invalidHandle: return L10n.Create.errorInvalidHandle
        case .invalidPhone: return L10n.Create.errorInvalidPhone
        case .invalidEmail: return L10n.Create.errorInvalidEmail
        case .invalidCoordinates: return L10n.Create.errorInvalidCoordinates
        }
    }
}

// MARK: - 入口

/// 创建页能进去的三种表单。
///
/// 码制**由入口决定**，不再让每个表单自己选——在小红书的表单里放七个码制胶囊，
/// 既跟用户要做的事无关，也把"填个用户名"这件小事撑成了一屏。
enum CreateMode: Hashable, Identifiable {
    /// 某个内容类型（社交平台 / 网址 / Wi-Fi…），统一出二维码。
    case type(CreateType)
    /// 指定的条形码码制，用户只填内容。
    case barcode(BarcodeKind)
    /// 自由输入 + 自选码制。
    case custom

    var id: String {
        switch self {
        case .type(let type): return "type_\(type.id)"
        case .barcode(let kind): return "barcode_\(kind.id)"
        case .custom: return "custom"
        }
    }

    var heroID: String { id }

    var tint: Color {
        switch self {
        case .type(let type): return type.tint
        case .barcode(let kind): return kind.tint
        case .custom: return Theme.Palette.primary
        }
    }

    /// 固定码制；`nil` 表示这个入口允许换码制（只有自定义允许）。
    var fixedKind: BarcodeKind? {
        switch self {
        case .type: return .qr
        case .barcode(let kind): return kind
        case .custom: return nil
        }
    }

    var canChooseFormat: Bool {
        if case .custom = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .type(let type): return type.title
        case .barcode(let kind): return kind.title
        case .custom: return L10n.Create.customTitle
        }
    }

    /// 表单要编码的字符串。返回 nil 表示"还没填够，别急着报错"。
    func payload(from draft: CreateDraft) throws -> String? {
        switch self {
        case .type(let type):
            return try type.payload(from: draft)
        case .barcode, .custom:
            let trimmed = draft.primary.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

// MARK: - BarcodeKind UI 拓展

extension BarcodeKind {
    var heroID: String { "barcode_\(id)" }

    var tint: Color {
        switch self {
        case .ean13: return Color(light: 0x1D61B0, dark: 0x3D88E0)
        case .ean8: return Color(light: 0x028090, dark: 0x22AAB8)
        case .code128: return Color(light: 0x6C5CE7, dark: 0x8F80F8)
        case .code39: return Color(light: 0x4A5568, dark: 0x718096)
        default: return Theme.Palette.primary
        }
    }

}
