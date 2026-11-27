import Foundation

#if DEBUG
/// 仅 Debug 构建生效：用环境变量指定启动页面，供 UI 验收与 App Store 截图自动化使用。
///
/// 用法：
///   SIMCTL_CHILD_LEITORQR_START_TAB=history xcrun simctl launch <device> com.leitorqr.app
///   SIMCTL_CHILD_LEITORQR_OVERLAY_SCREEN=paywall ...
enum DebugLaunchOptions {
    /// 任何截图/自动化参数出现时都跳过冷启动付费墙，
    /// 否则 `shot.sh --env LEITORQR_FAKE_CAMERA=1` 这类不带 --tab 的截图会拍到覆盖层。
    static var isAutomation: Bool {
        ProcessInfo.processInfo.environment.keys.contains { $0.hasPrefix("LEITORQR_") }
    }

    static var startTab: String? {
        ProcessInfo.processInfo.environment["LEITORQR_START_TAB"]
    }

    /// `LEITORQR_LANGUAGE=<.lproj 代码>`（如 en、de、es-419、zh-Hant、ar） 启动时直接切换语言，供四语言截图验收。
    /// 环境变量用语言/地区码（与 .lproj 同名），这里映射到 AppLanguage 的 rawValue。
    static var language: AppLanguage? {
        guard let raw = ProcessInfo.processInfo.environment["LEITORQR_LANGUAGE"] else { return nil }
        return AppLanguage(rawValue: raw) ?? AppLanguage.matching(lproj: raw)
    }

    static var overlayScreen: String? {
        ProcessInfo.processInfo.environment["LEITORQR_OVERLAY_SCREEN"]
    }

    /// `LEITORQR_FORCE_PREMIUM=1` 强制 PRO 态，用于验收付费功能页。
    static var forcePremium: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_FORCE_PREMIUM"] == "1"
    }

    /// `LEITORQR_WIFI_ALERT=restricted|failed` 结果页直接弹对应 Wi-Fi 提示，仅用于截图验收。
    static var wifiAlert: String? {
        ProcessInfo.processInfo.environment["LEITORQR_WIFI_ALERT"]
    }

    /// `LEITORQR_OPEN_CROWN=1` 启动后模拟点击页签右上角皇冠，
    /// 用于验收「未订阅进付费墙 / 已订阅进订阅管理」两条分支（simctl 无法点按）。
    static var openCrown: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_OPEN_CROWN"] == "1"
    }

    /// `LEITORQR_AUTO_OPEN=1` 强制开启网址自动打开，验收跳过结果页。
    static var autoOpen: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_AUTO_OPEN"] == "1"
    }

    /// `LEITORQR_AUTO_CONNECT_WIFI=1` 强制开启 Wi-Fi 自动连接。
    static var autoConnectWifi: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_AUTO_CONNECT_WIFI"] == "1"
    }

    /// `LEITORQR_WHITELIST=exemplo.pt,outro.com` 预置信任域名，验收风险卡降级为「已信任」。
    static var whitelistSeed: [String] {
        (ProcessInfo.processInfo.environment["LEITORQR_WHITELIST"] ?? "")
            .split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// `LEITORQR_OPEN_LANGUAGE=1` 打开 App 内语言选择页。
    static var openLanguage: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_OPEN_LANGUAGE"] == "1"
    }

    /// 插入一条示例历史，仅用于截图与验收。
    static var seedHistory: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_SEED_HISTORY"] == "1"
    }

    /// 示例历史的条数（默认 3）。填大值可以让列表铺满屏幕，
    /// 用来验收"内容从浮动底栏的玻璃下面滚过去"的折射效果。
    static var seedHistoryCount: Int {
        Int(ProcessInfo.processInfo.environment["LEITORQR_SEED_HISTORY_COUNT"] ?? "") ?? 3
    }

    /// 预填创建页内容并立即生成，便于截图验收。
    static var prefillGenerator: String? {
        ProcessInfo.processInfo.environment["LEITORQR_PREFILL_GENERATOR"]
    }

    /// `LEITORQR_CREATE_TYPE=wifi` 直接进对应类型的创建表单（跳过类型选择页）。
    static var createType: String? {
        ProcessInfo.processInfo.environment["LEITORQR_CREATE_TYPE"]
    }

    /// `LEITORQR_BARCODE_KIND=ean13` 预选码制，用来截图验收条形码预览。
    static var barcodeKind: String? {
        ProcessInfo.processInfo.environment["LEITORQR_BARCODE_KIND"]
    }

    /// `LEITORQR_CUSTOM_FORM=1` 直接打开悬浮按钮的自定义表单，用于截图验收。
    static var customForm: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_CUSTOM_FORM"] == "1"
    }

    /// `LEITORQR_CREATE_SCROLL=bottom` 自动滚动到创建页底部，用于截图验收二维码与条形码网格。
    static var createScrollBottom: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_CREATE_SCROLL"] == "bottom"
    }

    /// `LEITORQR_STYLE_SHEET=1` 创建表单出现后立刻弹出码样式面板，用于截图验收。
    static var styleSheet: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_STYLE_SHEET"] == "1"
    }

    /// `LEITORQR_CUSTOM_LOGO=1` 塞一张合成图片当"用户导入的图标"，
    /// 用来验收圆形裁剪与 aspect fill——自动化点不了系统选图器。
    static var customLogo: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_CUSTOM_LOGO"] == "1"
    }

    /// `LEITORQR_AUTOFOCUS=1` 进入表单就聚焦首个输入框，用来验收键盘收起按钮。
    static var autofocus: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_AUTOFOCUS"] == "1"
    }

    /// `LEITORQR_SEED_GENERATED=1` 往历史里写几条"自己做的码"（带备注），
    /// 用来验收缩略图、备注与详情页。
    static var seedGenerated: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_SEED_GENERATED"] == "1"
    }

    /// `LEITORQR_HISTORY_EMPTY=1` 强制保持历史为空，用于验收专属占位图。
    static var historyEmpty: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_EMPTY"] == "1"
    }

    /// `LEITORQR_HISTORY_SEARCH=wifi` 预填搜索关键词，用于验收搜索高亮与实时过滤。
    static var historySearch: String? {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_SEARCH"]
    }

    /// `LEITORQR_HISTORY_SORT=name` 预选排序方式 (newest, oldest, title, format)。
    static var historySort: String? {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_SORT"]
    }

    /// `LEITORQR_HISTORY_SOURCE=camera` 预选来源筛选 (all, camera, photos, generator)。
    static var historySource: String? {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_SOURCE"]
    }

    /// `LEITORQR_HISTORY_FILTER=wifi` 预选分类胶囊 (all, qr, barcode, website, wifi, hasNote)。
    static var historyFilter: String? {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_FILTER"]
    }

    /// `LEITORQR_HISTORY_SELECT=1` 让历史页启动即进入批量选择态，验收多选 UI。
    static var historySelectMode: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_SELECT"] == "1"
    }

    /// `LEITORQR_HISTORY_SELECT=1` 时预选的记录数（默认 2）。
    static var historySelectCount: Int {
        Int(ProcessInfo.processInfo.environment["LEITORQR_HISTORY_SELECT_COUNT"] ?? "") ?? 2
    }

    /// `LEITORQR_HISTORY_ADD=1` 自动弹出新增历史记录表单，用于验收新增与实时预览。
    static var historyAdd: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_HISTORY_ADD"] == "1"
    }

    /// `LEITORQR_FORCE_KEYBOARD_BAR=1` 假装键盘已弹出。
    /// 本机模拟器跑不了软键盘（没有 Simulator.app），拿它验收「Concluído」的排版。
    static var forceKeyboardBar: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_FORCE_KEYBOARD_BAR"] == "1"
    }

    /// `LEITORQR_OPEN_DETAIL=1` 历史页自动打开第一条详情，用来截图验收。
    static var openDetail: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_OPEN_DETAIL"] == "1"
    }

    /// `LEITORQR_AUTOSAVE_HISTORY=1` 进表单就执行一次"保存到历史"，
    /// 用来验证 生成 → 落库 → 历史列表 这条链路（自动化点不了按钮）。
    static var autosaveHistory: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_AUTOSAVE_HISTORY"] == "1"
    }

    /// 预置码样式，形如 `circle|true|1B2A4A|F7F3EA`（形状|图标|前景|背景）。
    static var stylePreset: String? {
        ProcessInfo.processInfo.environment["LEITORQR_STYLE_PRESET"]
    }

    /// `LEITORQR_TEMPLATE=holiday-pumpkin` 预选一套模板，用来截图验收模板装饰与历史还原。
    static var templateID: String? {
        ProcessInfo.processInfo.environment["LEITORQR_TEMPLATE"]
    }

    /// 用静态画面冒充摄像头预览，模拟器没有摄像头时也能验收扫描页的玻璃控件。
    /// 只影响渲染分支，不触碰 AVFoundation。
    static var fakeCamera: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_FAKE_CAMERA"] == "1"
    }

    /// 启动后注入一次识别（值为二维码内容），用来验收成功动画、触感与写历史链路。
    /// 逗号分隔可注入多个码，验收一帧多码的选择列表。
    /// 模拟器没有摄像头，没有这个开关就只能靠真机验证。
    static var simulatedScan: String? {
        ProcessInfo.processInfo.environment["LEITORQR_SIMULATE_SCAN"]
    }

    /// `LEITORQR_SHORTCUT_WIFI=1`：启动时等同于执行了快捷指令「扫码连 Wi-Fi」，
    /// 不用去快捷指令 App 里找，直接在 Xcode 里验收这个模式（可配合 `LEITORQR_SIMULATE_SCAN=WIFI:...`）。
    static var shortcutWiFi: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_SHORTCUT_WIFI"] == "1"
    }

    /// 把成功态定格多久（毫秒）。真机上这个态只有 0.45 秒，截图根本抓不住；
    /// 给个几千毫秒就能把"命中瞬间"稳定截下来做验收。
    static var successHoldMilliseconds: UInt64? {
        ProcessInfo.processInfo.environment["LEITORQR_SUCCESS_HOLD"].flatMap(UInt64.init)
    }

    /// 强制渲染扫描页（即使设备判定为无摄像头）。需与 `fakeCamera` 同时使用。
    static var forceScannerUI: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_FORCE_SCANNER_UI"] == "1"
    }

    /// 覆盖结果页示例链接，方便用可达的网址验收内置浏览器。
    static var resultURL: String? {
        ProcessInfo.processInfo.environment["LEITORQR_RESULT_URL"]
    }

    /// 结果页负载从文件读。vCard / iCalendar / EPC 付款码都是多行文本，
    /// 塞进环境变量既难转义又会被 shell 吃掉换行，走文件最省事。
    static var resultPayloadFile: String? {
        ProcessInfo.processInfo.environment["LEITORQR_RESULT_FILE"]
    }

    /// `contact` / `event`：直接拉起系统的新建联系人 / 新建日程界面。
    /// simctl 点不了按钮，没有这个开关就无法验收这两个系统编辑器的接入。
    static var autoCompose: String? {
        ProcessInfo.processInfo.environment["LEITORQR_AUTO_COMPOSE"]
    }

    /// 结果页要展示的负载：文件优先，其次 `RESULT_URL`，最后默认示例链接。
    static var resultPayload: String {
        if let path = resultPayloadFile,
           let text = try? String(contentsOfFile: path, encoding: .utf8),
           !text.isEmpty {
            return text
        }
        return resultURL ?? "https://exemplo.pt/menu"
    }

    /// 模拟器没有闪光灯，强制显示手电筒按钮，用来验收「相册 + 手电筒」双钮排版。
    /// 取值 `1` 显示（关闭态），`on` 显示且为开启态。
    static var fakeTorch: Bool {
        ["1", "on"].contains(ProcessInfo.processInfo.environment["LEITORQR_FAKE_TORCH"] ?? "")
    }

    /// 假手电筒是否以开启态启动，用于验收染色玻璃。
    static var fakeTorchStartsOn: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_FAKE_TORCH"] == "on"
    }

    /// `LEITORQR_FORCE_TRIAL=0` 或 `1` 模拟「后台配了 / 没配 7 天试用」，仅用于截图验收。
    /// 不设时完全以 StoreKit 返回的 offer 为准（商品没加载 → 不显示试用）。
    static var forceTrial: Bool? {
        guard let raw = ProcessInfo.processInfo.environment["LEITORQR_FORCE_TRIAL"] else { return nil }
        return raw == "1"
    }

    /// `LEITORQR_PAYWALL_REASON=scan|limit|feature|onboarding` 指定 DEBUG 付费墙的情境文案，用于截图验收。
    static var paywallReason: String? {
        ProcessInfo.processInfo.environment["LEITORQR_PAYWALL_REASON"]?.lowercased()
    }

    /// `LEITORQR_ONBOARDING=1` 强制显示首次启动引导（不管之前是否看过）。
    static var forceOnboarding: Bool {
        ProcessInfo.processInfo.environment["LEITORQR_ONBOARDING"] == "1"
    }

}
#endif
