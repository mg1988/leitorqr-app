import SwiftUI

/// 二维码外观。只做"能扫得出来"的定制：
/// 颜色、码点形状、中心图标——不做渐变、不做高光，那些会把对比度吃掉。
///
/// `Codable`：历史记录要把样式一起存下来，下次打开还是当初那个样子。
struct QRCodeStyle: Equatable, Codable {

    var foregroundHex: UInt32 = Palette.ink
    var backgroundHex: UInt32 = Palette.paper
    var dotShape: DotShape = .rounded
    /// 中心图标的来源。品牌图标与用户自己的图片共用同一个"挖洞"位置，
    /// 所以用单选而不是两个开关——两个都开就得回答"到底画哪个"。
    var logoSource: LogoSource = .none
    /// 选中的成套模板 ID。`nil` = 只用手动颜色/形状，不画外围装饰。
    ///
    /// 故意存 ID 而不是存一张合成好的背景图：历史只要留这段 JSON 就能逐像素重画，
    /// 数据库不会因为 12 款模板多存 12 张位图。Optional 让旧记录的 JSON 直接兼容。
    var templateID: String?
    /// 定位角（三个角的「眼睛」）形状。nil = 圆角（旧版本记录没有这个字段，按原来的样子画）。
    /// Optional 是为了兼容历史里存的旧 JSON：合成的 Decodable 对可选字段用 decodeIfPresent。
    var eyeShape: EyeShape?
    /// 定位角外框颜色。nil = 跟随码点前景色。
    var eyeHex: UInt32?
    /// 定位角内块形状 / 颜色。nil = 跟随外框。
    var eyeBallShape: EyeShape?
    var eyeBallHex: UInt32?
    /// 品牌图标底下那块方块的颜色。nil = 用定位角颜色。
    /// 从首页品牌入口进来时设成品牌色（Instagram 粉、WhatsApp 绿…），换精选样式 / 模板都保留——
    /// 它是「这是哪个平台」的标识，不是装饰色。
    var logoTileHex: UInt32?

    var foreground: Color { Color(hex: foregroundHex) }
    var resolvedEyeShape: EyeShape { eyeShape ?? .rounded }
    var resolvedEyeHex: UInt32 { eyeHex ?? foregroundHex }
    var resolvedEyeBallShape: EyeShape { eyeBallShape ?? resolvedEyeShape }
    var resolvedEyeBallHex: UInt32 { eyeBallHex ?? resolvedEyeHex }

    /// 这套样式里有没有**买断后才能保存 / 分享**的部分。
    /// 编辑时可以随便试（先看到效果再决定买不买），只在保存 / 分享时拦。
    var usesPremiumFeatures: Bool {
        template?.isPremium == true
            || dotShape.isPremium
            || resolvedEyeShape.isPremium
            || resolvedEyeBallShape.isPremium
            || logoSource == .custom
    }
    var background: Color { Color(hex: backgroundHex) }

    /// 当前模板。ID 指向已下线的模板时返回 nil，渲染自动退回普通二维码。
    var template: CodeTemplate? {
        templateID.flatMap(CodeTemplate.withID)
    }

    /// 前景色板：都是深色，配白底都有 7:1 以上。
    static let foregroundSwatches: [UInt32] = [
        0x111418, // 墨
        0x1B2A4A, // 深海蓝
        0x246BCE, // 品牌蓝
        0x0E5C55, // 松绿
        0x1F6B3A, // 森林
        0x8C1C2B, // 酒红
        0x5B2A86, // 紫
        0x7A4A16  // 焦糖
    ]

    /// 背景色板：都够浅，换掉只是换气质，不影响可读。
    static let backgroundSwatches: [UInt32] = [
        0xFFFFFF, // 白
        0xF7F3EA, // 米
        0xEFF2F6, // 雾
        0xE9F1FB, // 淡蓝
        0xF7ECEC  // 淡粉
    ]

    private enum Palette {
        static let ink: UInt32 = 0x111418
        static let paper: UInt32 = 0xFFFFFF
    }

    /// WCAG 对比度。低于 3 基本只能靠运气，界面上要直说。
    var contrastRatio: Double {
        let a = Self.relativeLuminance(foregroundHex)
        let b = Self.relativeLuminance(backgroundHex)
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var isLowContrast: Bool { contrastRatio < 3 }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw & 0xFF) / 255
            return value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16)
            + 0.7152 * channel(hex >> 8)
            + 0.0722 * channel(hex)
    }
}

/// 中心图标的来源。
enum LogoSource: String, CaseIterable, Identifiable, Codable {
    case none
    case brand
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.Create.logoNone
        case .brand: return L10n.Create.logoBrand
        case .custom: return L10n.Create.logoCustom
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "slash.circle"
        case .brand: return "app.badge"
        case .custom: return "photo"
        }
    }
}

/// 码点形状。
/// - square / rounded / circle：免费。
/// - dots（留白的小圆点）/ fluid（液态：相邻码点连成一片，外角圆、内角有圆滑过渡）/
///   classy（只圆左上、右下两个角的「书法」形）/ bars（竖向胶囊条）：PRO。
/// rawValue 不能改：历史记录里存的就是它。新增形状必须用 `scripts/decode_barcode.swift` 跑一遍再上线。
enum DotShape: String, CaseIterable, Identifiable, Codable {
    case square
    case rounded
    case circle
    case dots
    case fluid
    case classy
    case bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return L10n.Create.shapeSquare
        case .rounded: return L10n.Create.shapeRounded
        case .circle: return L10n.Create.shapeCircle
        case .dots: return L10n.Create.shapeDots
        case .fluid: return L10n.Create.shapeFluid
        case .classy: return L10n.Create.shapeClassy
        case .bars: return L10n.Create.shapeBars
        }
    }

    var symbolName: String {
        switch self {
        case .square: return "square.fill"
        case .rounded: return "app.fill"
        case .circle: return "circle.fill"
        case .dots: return "circle.grid.3x3.fill"
        case .fluid: return "drop.fill"
        case .classy: return "leaf.fill"
        case .bars: return "pause.fill"
        }
    }

    var isPremium: Bool {
        switch self {
        case .square, .rounded, .circle: return false
        case .dots, .fluid, .classy, .bars: return true
        }
    }
}

/// 定位角形状。square / rounded 免费，circle / leaf / drop 是 PRO。
/// drop（水滴）：三个大圆角 + 一个朝向码中心的小角。
enum EyeShape: String, CaseIterable, Identifiable, Codable {
    case square
    case rounded
    case circle
    case leaf
    case drop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return L10n.Create.eyeSquare
        case .rounded: return L10n.Create.eyeRounded
        case .circle: return L10n.Create.eyeCircle
        case .leaf: return L10n.Create.eyeLeaf
        case .drop: return L10n.Create.eyeDrop
        }
    }

    var isPremium: Bool {
        switch self {
        case .square, .rounded: return false
        case .circle, .leaf, .drop: return true
        }
    }
}

/// 精选样式：一整套「码点 + 定位角外框 / 内块 + 配色」，在创建页一排横向卡片里一键切换。
/// 只改码本身的外观，不带外围装饰（那是模板的事），选中时会清掉模板，保留中心图标的选择。
/// 配色规则：深色码点 + 浅色底（反色码在不少扫码器上读不出来）；定位角外框用一个更亮的强调色，
/// 内块回到码点色，形成「双色眼」；所有强调色对底色的对比度都 ≥ 3:1。
struct QRStylePreset: Identifiable, Equatable {
    let id: String
    let foregroundHex: UInt32
    let backgroundHex: UInt32
    let dotShape: DotShape
    let eyeShape: EyeShape
    var ballShape: EyeShape? = nil
    /// 外框颜色，nil = 码点色。
    var eyeHex: UInt32? = nil
    /// 内块颜色，nil = 跟外框。
    var ballHex: UInt32? = nil

    var isPremium: Bool {
        dotShape.isPremium || eyeShape.isPremium || (ballShape?.isPremium ?? false)
    }

    var name: String {
        switch id {
        case "ink": return L10n.Create.presetInk
        case "sapphire": return L10n.Create.presetSapphire
        case "classic": return L10n.Create.presetClassic
        case "midnight": return L10n.Create.presetMidnight
        case "coral": return L10n.Create.presetCoral
        case "forest": return L10n.Create.presetForest
        case "violet": return L10n.Create.presetViolet
        default: return L10n.Create.presetBordeaux
        }
    }

    func applying(to style: QRCodeStyle) -> QRCodeStyle {
        var next = style
        next.foregroundHex = foregroundHex
        next.backgroundHex = backgroundHex
        next.dotShape = dotShape
        next.eyeShape = eyeShape
        next.eyeBallShape = ballShape
        next.eyeHex = eyeHex
        next.eyeBallHex = ballHex
        next.templateID = nil
        return next
    }

    func matches(_ style: QRCodeStyle) -> Bool {
        let frame = eyeHex ?? foregroundHex
        return style.templateID == nil
            && style.foregroundHex == foregroundHex
            && style.backgroundHex == backgroundHex
            && style.dotShape == dotShape
            && style.resolvedEyeShape == eyeShape
            && style.resolvedEyeBallShape == (ballShape ?? eyeShape)
            && style.resolvedEyeHex == frame
            && style.resolvedEyeBallHex == (ballHex ?? frame)
    }

    /// 前三款免费。默认样式（墨色圆角 + 圆角眼）不在精选里，选中环会落在「更多」上。
    static let all: [QRStylePreset] = [
        QRStylePreset(id: "ink", foregroundHex: 0x101418, backgroundHex: 0xFFFFFF,
                      dotShape: .fluid, eyeShape: .rounded),
        QRStylePreset(id: "sapphire", foregroundHex: 0x14286B, backgroundHex: 0xFFFFFF,
                      dotShape: .fluid, eyeShape: .rounded, ballShape: .circle,
                      eyeHex: 0x2449E6, ballHex: 0x14286B),
        QRStylePreset(id: "classic", foregroundHex: 0x101418, backgroundHex: 0xFFFFFF,
                      dotShape: .rounded, eyeShape: .rounded),
        QRStylePreset(id: "midnight", foregroundHex: 0x0B1B3F, backgroundHex: 0xEEF3FF,
                      dotShape: .dots, eyeShape: .circle, ballShape: .circle,
                      eyeHex: 0x2449E6, ballHex: 0x0B1B3F),
        QRStylePreset(id: "coral", foregroundHex: 0x5C2312, backgroundHex: 0xFFF3EC,
                      dotShape: .fluid, eyeShape: .leaf,
                      eyeHex: 0xC8441F, ballHex: 0x5C2312),
        QRStylePreset(id: "forest", foregroundHex: 0x123D2A, backgroundHex: 0xEFF6F0,
                      dotShape: .classy, eyeShape: .leaf, ballShape: .circle,
                      eyeHex: 0x1C7A4B, ballHex: 0x123D2A),
        QRStylePreset(id: "violet", foregroundHex: 0x2E1A86, backgroundHex: 0xF3F0FF,
                      dotShape: .dots, eyeShape: .drop, ballShape: .circle,
                      eyeHex: 0x5B3FE0, ballHex: 0x2E1A86),
        QRStylePreset(id: "bordeaux", foregroundHex: 0x5A1128, backgroundHex: 0xFBEFF2,
                      dotShape: .classy, eyeShape: .rounded, ballShape: .leaf,
                      eyeHex: 0xA3214A, ballHex: 0x5A1128)
    ]
}
