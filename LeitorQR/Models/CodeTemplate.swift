import SwiftUI

/// 成套的二维码外观预设。
///
/// 与 `QRCodeStyle` 的关系：模板只是**一份预设值**，选中后把颜色、码点形状写进 style，
/// 再把 `templateID` 记下来。真正画装饰靠 `TemplateRenderer` 按这个 ID 重画，
/// 所以历史记录只要存 style 的 JSON 就能完整还原，不需要额外存背景位图。
///
/// 装饰全部是 Core Graphics 自绘的几何图形（不是插画素材），并且只画在中央白卡之外。
enum CodeTemplateCategory: String, CaseIterable, Identifiable {
    case all
    case classic
    case social
    case holiday
    case love
    case birthday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.Templates.all
        case .classic: return L10n.Templates.classic
        case .social: return L10n.Templates.social
        case .holiday: return L10n.Templates.holiday
        case .love: return L10n.Templates.love
        case .birthday: return L10n.Templates.birthday
        }
    }
}

/// 一组装饰元素。每个 case 对应 `TemplateRenderer` 里的一段自绘路径。
enum TemplateDecoration: String {
    case none
    case dots
    case sparkles
    case stars
    case confetti
    case rose
    case pumpkin
    case ghost
    case snow
    case hearts
    case balloons
    case gift
    case comicBubble
}

struct CodeTemplate: Identifiable, Equatable {
    let id: String
    let category: CodeTemplateCategory
    /// 码点的前景 / 码区底色。
    let foregroundHex: UInt32
    let backgroundHex: UInt32
    /// 中央白卡、外围画布、装饰主色 / 辅色。
    let cardHex: UInt32
    let canvasHex: UInt32
    let accentHex: UInt32
    let accentSecondaryHex: UInt32
    let dotShape: DotShape
    let decoration: TemplateDecoration
    var isPremium: Bool = false

    /// 套用到现有样式上：保留用户选的中心图标来源，其余按模板覆盖。
    func applying(to style: QRCodeStyle) -> QRCodeStyle {
        var next = style
        next.foregroundHex = foregroundHex
        next.backgroundHex = backgroundHex
        next.dotShape = dotShape
        next.templateID = id
        // 模板有自己的配色：定位角跟随模板前景色，不沿用上一个精选样式的强调色。
        next.eyeHex = nil
        next.eyeBallHex = nil
        return next
    }

    /// 模板缩略图用的样式（网格里渲染固定的示例内容）。
    var previewStyle: QRCodeStyle {
        applying(to: QRCodeStyle())
    }

    var cardColor: Color { Color(hex: cardHex) }
    var canvasColor: Color { Color(hex: canvasHex) }

    /// 网格卡片下方的短名字。key 走 L10n，不在模型里写裸文案。
    var name: String {
        switch id {
        case "classic-ink": return L10n.Templates.nameClassicInk
        case "classic-blue": return L10n.Templates.nameClassicBlue
        case "social-green": return L10n.Templates.nameSocialGreen
        case "social-night": return L10n.Templates.nameSocialNight
        case "social-sunset": return L10n.Templates.nameSocialSunset
        case "social-comic": return L10n.Templates.nameSocialComic
        case "holiday-pumpkin": return L10n.Templates.nameHolidayPumpkin
        case "holiday-ghost": return L10n.Templates.nameHolidayGhost
        case "holiday-snow": return L10n.Templates.nameHolidaySnow
        case "love-heart": return L10n.Templates.nameLoveHeart
        case "love-rose": return L10n.Templates.nameLoveRose
        case "birthday-balloons": return L10n.Templates.nameBirthdayBalloons
        case "birthday-gift": return L10n.Templates.nameBirthdayGift
        default: return L10n.Templates.none
        }
    }

    /// 码区前景统一走「深而饱和」：亮度压到近黑，但保留色相。
    ///
    /// 第一版为了稳解码一刀切压成近黑，12 款之间的色相区分被抹平了——
    /// 样式系统最该有的"一眼看出不同"没了，方向就错了。现在改为深色相：
    /// 深蓝 0x12408F、墨绿 0x0B6B3A、酒红 0x94122F、宝蓝 0x1B4FA8……亮度仍低，
    /// 色相仍然分得清。鲜艳色继续交给外围装饰（accentHex）。
    ///
    /// 画布配色不按"同一色系家族"分组，而是按**色相铺开**排。
    /// 第二版踩过的坑：薄荷绿和雪、桃色和奶橘、樱粉和玫瑰粉挤在一起，
    /// 网格里三对几乎分不开。现在 12 款各占一个色相带：
    /// 冷灰 / 淡蓝 / 黄绿 / 深藏青 / 奶黄 / 南瓜橘 / 深紫罗兰 / 冰蓝 / 樱粉 / 象牙 / 薄荷青 / 鲑粉。
    ///
    /// 已知无关项：**长内容（30+ 字符）在自绘圆角码点下 macOS Vision 检不出**，
    /// 黑白对照 12/12 复现过，属于既有缺陷，与配色和模板都无关。
    ///
    /// 另一条实测出来的硬规则：**装饰主色不能和画布同色系**。
    /// 南瓜用「橙装饰 + 橙画布」时，Vision 检不出这张图（裁出白卡单独解是好的，
    /// 说明码本身没问题，是外围中间调把二值化搞乱了）；把画布换成深李子色、
    /// 装饰换成亮橙，立刻恢复可解。所以配色不能只看"好不好看"，还要看
    /// 装饰与画布之间有没有足够亮度+色相落差。
    static let all: [CodeTemplate] = [
        // MARK: 经典
        CodeTemplate(
            id: "classic-ink", category: .classic,
            foregroundHex: 0x111418, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xD8DDE5,
            accentHex: 0x8A96A6, accentSecondaryHex: 0xC8D0DA,
            dotShape: .square, decoration: .none
        ),
        CodeTemplate(
            id: "classic-blue", category: .classic,
            foregroundHex: 0x12408F, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xDDE9F8,
            accentHex: 0x246BCE, accentSecondaryHex: 0x9CC0EE,
            dotShape: .rounded, decoration: .dots
        ),

        // MARK: 社交
        CodeTemplate(
            id: "social-green", category: .social,
            foregroundHex: 0x0B6B3A, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xE8F2D6,
            accentHex: 0x12A45F, accentSecondaryHex: 0x8ED7AC,
            dotShape: .rounded, decoration: .sparkles
        ),
        CodeTemplate(
            id: "social-night", category: .social,
            foregroundHex: 0x1B4FA8, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0x0A1E38,
            accentHex: 0x8DB6EC, accentSecondaryHex: 0x4C8BE0,
            dotShape: .circle, decoration: .stars,
            isPremium: true
        ),
        CodeTemplate(
            id: "social-sunset", category: .social,
            foregroundHex: 0x8A3206, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xFDF0CF,
            accentHex: 0xE07B2E, accentSecondaryHex: 0xD9543F,
            dotShape: .rounded, decoration: .confetti,
            isPremium: true
        ),
        CodeTemplate(
            id: "social-comic", category: .social,
            foregroundHex: 0x18181B, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xFEF9C3,
            accentHex: 0xFACC15, accentSecondaryHex: 0xEF4444,
            dotShape: .square, decoration: .comicBubble,
            isPremium: true
        ),

        // MARK: 节日
        CodeTemplate(
            id: "holiday-pumpkin", category: .holiday,
            foregroundHex: 0x2C2431, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0x331E27,
            accentHex: 0xF08A2E, accentSecondaryHex: 0xC2410C,
            dotShape: .circle, decoration: .pumpkin,
            isPremium: true
        ),
        CodeTemplate(
            id: "holiday-ghost", category: .holiday,
            foregroundHex: 0x1E1733, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0x2B1B4A,
            accentHex: 0xF2F4FA, accentSecondaryHex: 0x8E9BC4,
            dotShape: .rounded, decoration: .ghost,
            isPremium: true
        ),
        CodeTemplate(
            id: "holiday-snow", category: .holiday,
            foregroundHex: 0x13553F, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xC9DEEE,
            accentHex: 0x1D6E7A, accentSecondaryHex: 0x2E7D63,
            dotShape: .rounded, decoration: .snow,
            isPremium: true
        ),

        // MARK: 爱情
        CodeTemplate(
            id: "love-heart", category: .love,
            foregroundHex: 0x94122F, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xFBDDE5,
            accentHex: 0xD9436C, accentSecondaryHex: 0xF3A0B7,
            dotShape: .circle, decoration: .hearts,
            isPremium: true
        ),
        CodeTemplate(
            id: "love-rose", category: .love,
            foregroundHex: 0x6B2438, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xEFE7DE,
            accentHex: 0xA34862, accentSecondaryHex: 0xC9899B,
            dotShape: .rounded, decoration: .rose,
            isPremium: true
        ),

        // MARK: 生日
        CodeTemplate(
            id: "birthday-balloons", category: .birthday,
            foregroundHex: 0x2456B8, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xD6EFE9,
            accentHex: 0x3C72D6, accentSecondaryHex: 0xE9A23B,
            dotShape: .circle, decoration: .balloons,
            isPremium: true
        ),
        CodeTemplate(
            id: "birthday-gift", category: .birthday,
            foregroundHex: 0x116B4A, backgroundHex: 0xFFFFFF,
            cardHex: 0xFFFFFF, canvasHex: 0xFBE0D2,
            accentHex: 0x2E8B62, accentSecondaryHex: 0xD9604F,
            dotShape: .rounded, decoration: .gift,
            isPremium: true
        )
    ]

    static func withID(_ id: String) -> CodeTemplate? {
        all.first { $0.id == id }
    }

    static func inCategory(_ category: CodeTemplateCategory) -> [CodeTemplate] {
        category == .all ? all : all.filter { $0.category == category }
    }
}
