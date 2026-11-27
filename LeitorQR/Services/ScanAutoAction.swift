import AppIntents
import Combine
import Foundation

/// 扫描后自动处理的独立开关。三组功能互不依赖，用户可分别开关。
enum ScanAutoActionSettings {
    static let wifiAutoConnectKey = "scan.auto.wifi.connect"
    static let websiteAutoOpenKey = "scan.auto.website.open"
    /// 电话 / 短信 / 邮件 / 地图：都是交给系统 App 处理，归成一组。
    static let linkAutoOpenKey = "scan.auto.link.open"

    /// 默认关闭：自动打开会跳过结果页，必须用户明确知情后开启。
    static let wifiAutoConnectDefault = false
    static let websiteAutoOpenDefault = false
    static let linkAutoOpenDefault = false
}

/// 扫描命中后该「直接执行」还是「弹结果页让用户确认」。
///
/// 决策原则：
/// 1. 多码永远走选择列表——一次执行多个动作会失控。
/// 2. Wi-Fi 只有开了开关、且能解析出网络才自动连；连不上仍需回到结果页。
/// 3. 网址只有开了开关、且风险等级为 low 才自动打开；
///    可疑网址一律保留结果页，让刚做的防钓鱼提示真正起作用。
/// 4. 电话/短信/邮件/地图只认本类型 scheme（`externalAction` 已校验），
///    系统打开前后都会让用户确认，不存在"扫一下就拨出去"。
/// 5. 联系人（vCard）、日历事件、EPC 付款码、加密地址**一律不自动**：
///    前两者是往通讯录/日历里写，后两者会导出一笔转账或拉起钱包，
///    全部必须先让用户在结果页看清内容再点按钮。
enum ScanAutoActionResolver {
    enum Decision {
        case showResults
        case autoConnectWiFi(WiFiNetwork)
        case autoOpenWebsite(URL)
        /// tel: / sms: / mailto: / geo:
        case autoOpenSystemAction(URL)
    }

    static func decide(
        contents: [ScanContent],
        wifiAutoConnect: Bool,
        websiteAutoOpen: Bool,
        linkAutoOpen: Bool
    ) -> Decision {
        // 多码不做任何自动动作。
        guard contents.count == 1, let content = contents.first else {
            return .showResults
        }

        switch content.type {
        case .wifi:
            guard wifiAutoConnect,
                  let network = WiFiNetwork.parse(content.rawValue) else {
                return .showResults
            }
            return .autoConnectWiFi(network)

        case .url:
            guard websiteAutoOpen,
                  let url = content.openableURL else {
                return .showResults
            }
            // 白名单域名视为可信；否则只有零命中（low）才自动打开。
            let trusted = RiskStore.isTrusted(url.host ?? "")
            let assessment = QRRiskAnalyzer.analyze(url)
            if trusted || assessment.level == .low {
                return .autoOpenWebsite(url)
            }
            return .showResults

        case .phone, .email, .sms, .location:
            guard linkAutoOpen,
                  let action = content.externalAction else {
                return .showResults
            }
            return .autoOpenSystemAction(action.url)

        case .text, .barcode, .contact, .event, .payment, .crypto:
            return .showResults
        }
    }
}

// MARK: - ============ 快捷指令 ============
//
// 放在这个已在工程里的文件中，而不是单独的新文件：工程由 XcodeGen 管理，
// 新增 .swift 文件要先跑 `xcodegen generate` 才会被编译（11-27 曾因此报
// 「Cannot find 'ShortcutRouter' in scope」）。

// MARK: - 快捷指令（App Intents）
//
// 两个入口，都在主 App 里执行（不需要扩展 target）：
// A.「扫码连 Wi-Fi」`ScanWiFiIntent`：打开扫描页，下一次扫到 Wi-Fi 码直接连接，不弹结果页。
//    注册为 App Shortcut：自动出现在快捷指令 App、Spotlight、操作按钮（Action Button）、Siri。
// B.「连接 Wi-Fi 网络」`ConnectWiFiIntent`：接收一段 `WIFI:` 文本并连接，返回是否成功。
//    只作为快捷指令 App 里的动作，用户可以接在系统「扫描二维码」动作后面自由组合。
//
// 系统限制（绕不过去）：
// - 每次加入网络系统都会弹窗确认，任何 App 都不能静默连接；
// - `NEHotspotConfigurationManager.apply` 要求 App 在前台，所以两个 intent 都会打开 App；
// - 需要 Hotspot Configuration entitlement（付费开发者账号），否则返回「请手动加入」。

/// 快捷指令 → 扫描页的路由。intent 只改这里的状态，扫描页自己消费，避免 intent 直接操作视图。
@MainActor
final class ShortcutRouter: ObservableObject {

    static let shared = ShortcutRouter()

    /// 「扫码连 Wi-Fi」已触发：扫描页下一次扫到 Wi-Fi 码直接连接（无视设置里的开关）。
    /// 扫到 Wi-Fi 码或 App 进入后台时失效，不会长期改变扫码行为。
    @Published private(set) var isWiFiScanArmed = false

    private init() {}

    func armWiFiScan() {
        isWiFiScanArmed = true
        // 收掉可能挡在扫描页前面的弹层，切到扫描页签。
        PaywallTriggerManager.shared.isPaywallPresented = false
        ProPortal.shared.isSubscriptionPresented = false
        NotificationCenter.default.post(name: .switchToScanTab, object: nil)
    }

    func consumeWiFiScan() {
        guard isWiFiScanArmed else { return }
        isWiFiScanArmed = false
    }
}

// MARK: - A. 扫码连 Wi-Fi

struct ScanWiFiIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.scanWifi.title"
    static let description = IntentDescription("intent.scanWifi.description")
    /// 连接 Wi-Fi 的系统接口要求 App 在前台，扫码也需要相机画面。
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutRouter.shared.armWiFiScan()
        return .result()
    }
}

// MARK: - B. 连接 Wi-Fi 网络

struct ConnectWiFiIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.connectWifi.title"
    static let description = IntentDescription("intent.connectWifi.description")
    /// `NEHotspotConfigurationManager.apply` 在后台会返回 `applicationIsNotInForeground`。
    static let openAppWhenRun = true

    @Parameter(title: "intent.connectWifi.payload")
    var payload: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let network = WiFiNetwork.parse(text) else {
            throw WiFiIntentError.notWiFiCode
        }

        let result = await WiFiConnector.join(network)
        if result == .joined {
            let message = String(format: L10n.Result.wifiJoinedDetail, network.ssid)
            return .result(value: true, dialog: "\(message)")
        }
        // 连不上不抛错，返回 false：用户的快捷指令可以据此分支（比如改为打开设置）。
        return .result(value: false, dialog: "\(Self.failureMessage(for: result))")
    }

    /// 和结果页同一套文案：标题 + 下一步怎么办。
    private static func failureMessage(for result: WiFiJoinResult) -> String {
        let pair: (String, String)
        switch result {
        case .joined:
            return ""
        case .userDenied:
            pair = (L10n.Result.wifiDenied, L10n.Result.wifiDeniedDetail)
        case .invalidCredentials:
            pair = (L10n.Result.wifiFailed, L10n.Result.wifiInvalidDetail)
        case .unsupported:
            pair = (L10n.Result.wifiUnsupported, L10n.Result.wifiUnsupportedDetail)
        case .notPermitted:
            pair = (L10n.Result.wifiRestricted, L10n.Result.wifiRestrictedDetail)
        case .failed:
            pair = (L10n.Result.wifiFailed, L10n.Result.wifiFailedDetail)
        }
        return "\(pair.0)\n\(pair.1)"
    }
}

enum WiFiIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notWiFiCode

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notWiFiCode: return "intent.connectWifi.notWifi"
        }
    }
}

// MARK: - App Shortcuts

/// 注册后无需用户手动添加：安装即出现在快捷指令 App、Spotlight，并可绑定到操作按钮。
/// 唤起短语的翻译在 `Resources/AppShortcuts.xcstrings`（键是下面的葡语原文）。
struct LeitorQRShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanWiFiIntent(),
            phrases: [
                "Ler Wi-Fi com \(.applicationName)",
                "Conectar ao Wi-Fi com \(.applicationName)"
            ],
            shortTitle: "intent.scanWifi.short",
            systemImageName: "wifi"
        )
    }
}
