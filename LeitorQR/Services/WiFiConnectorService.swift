import Foundation
import NetworkExtension

/// 从 `WIFI:` 负载解析出的网络信息。
///
/// 标准格式：`WIFI:T:WPA;S: ssid;P: password;H:true;;`
/// 字段内的 `\;` `\,` `\:` `\"` `\\` 必须反转义后再交给系统 API。
struct WiFiNetwork {
    enum Security {
        case wpa
        case wep
        case open
        /// EAP 需要证书/身份配置，`NEHotspotConfiguration` 的简单初始化器不支持。
        case enterprise
    }

    let ssid: String
    let password: String
    let security: Security
    let isHidden: Bool

    static func parse(_ payload: String) -> WiFiNetwork? {
        guard payload.uppercased().hasPrefix("WIFI:") else { return nil }
        let fields = parseFields(String(payload.dropFirst(5)))
        guard let ssid = fields["S"], !ssid.isEmpty else { return nil }

        let type = (fields["T"] ?? "").uppercased()
        let security: Security
        switch type {
        case "WPA", "WPA2", "WPA/WPA2", "":
            security = .wpa
        case "WEP":
            security = .wep
        case "NOPASS", "OPEN":
            security = .open
        default:
            security = .enterprise
        }

        return WiFiNetwork(
            ssid: ssid,
            password: fields["P"] ?? "",
            security: security,
            isHidden: (fields["H"] ?? "").uppercased() == "TRUE"
        )
    }

    /// 按 `;` 切分并反转义。不能用 `components(separatedBy: ";")`——密码里允许出现 `\;`。
    private static func parseFields(_ body: String) -> [String: String] {
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

/// 扫码后加入 Wi-Fi。
///
/// 两个硬约束（实测/官方文档）：
/// 1. 必须在 Apple Developer 为 bundle id 开启 **Hotspot Configuration** capability，
///    工程默认 CODE_SIGN_ENTITLEMENTS 已指向 `Support/LeitorQR-Hotspot.entitlements`。
///    无 entitlement 时（临时切回空 entitlements 的自签名调试）`apply` 必失败：
///    Apple DTS 确认 completion 返回 `.internal`（这里映射成 `.notPermitted`），
///    不会崩溃，UI 会提示受限并引导手动连接。模拟器没有真实 Wi-Fi，只能真机验证。
/// 2. 系统仍会弹窗让用户确认加入，无法静默连接。且 `apply` 成功只代表"配置已提交"，
///    iOS 26 起 `NEHotspotNetwork.fetchCurrent` 会被拒，不能拿它回读 SSID 当判据。
enum WiFiJoinResult {
    case joined
    case userDenied
    case unsupported
    case invalidCredentials
    /// 没有 Hotspot Configuration entitlement（自签名 / 个人账号）。
    /// 必须与 `.failed` 区分：把「App 没权限」报成「网络不在范围内」会让用户
    /// 一直在路由器旁边打转，永远找不到真正的原因。
    case notPermitted
    case failed
}

@MainActor
enum WiFiConnector {
    static func join(_ network: WiFiNetwork) async -> WiFiJoinResult {
        guard network.security != .enterprise, !network.ssid.isEmpty else {
            return .unsupported
        }
        if network.security != .open && network.password.isEmpty {
            return .invalidCredentials
        }

        let configuration: NEHotspotConfiguration
        switch network.security {
        case .open:
            configuration = NEHotspotConfiguration(ssid: network.ssid)
        case .wep:
            configuration = NEHotspotConfiguration(
                ssid: network.ssid, passphrase: network.password, isWEP: true
            )
        case .wpa:
            configuration = NEHotspotConfiguration(
                ssid: network.ssid, passphrase: network.password, isWEP: false
            )
        case .enterprise:
            return .unsupported
        }
        // SSID 来自二维码，内容攻击者可控：一律 joinOnce 临时入网。
        // 若永久保存，扫一次恶意热点码就会让 iOS 之后持续优先连它（双胞胎热点持久 MITM）。
        // 常用网络让用户在系统设置里自己勾选「自动加入」。
        configuration.joinOnce = true
        configuration.hidden = network.isHidden

        let manager = NEHotspotConfigurationManager.shared
        // 不要预删既有配置：removeConfiguration 只能删自己创建的，删用户已保存的
        // 同名合法网络等于给攻击者"顶替已保存网络"的入口；joinOnce 配置本身
        // 不会持久化，也无残留需要清理。

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.apply(configuration) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: ()) }
                }
            }
            return .joined
        } catch {
            // NEHotspotConfigurationError 在 Swift 里是 RawRepresentable 的枚举，
            // 回调给的是 NSError，必须走 domain + code 还原，不能直接 as?。
            let nsError = error as NSError
            guard nsError.domain == NEHotspotConfigurationErrorDomain,
                  let code = NEHotspotConfigurationError(rawValue: nsError.code) else {
                return .failed
            }
            switch code {
            case .userDenied, .userUnauthorized, .systemDenied:
                return .userDenied
            case .invalidSSID, .invalidWPAPassphrase, .invalidWEPPassphrase, .invalid:
                return .invalidCredentials
            case .joinOnceNotSupported, .applicationIsNotInForeground, .invalidEAPSettings:
                return .unsupported
            // `.internal` 是缺 entitlement 时的实际返回码（Apple DTS 论坛 819133 确认）。
            // 除此之外还有系统内部错误，但两者对用户的处置一样：当前版本连不上，
            // 只能手动去系统设置里加入该网络。
            case .internal:
                return .notPermitted
            default:
                return .failed
            }
        }
    }
}
