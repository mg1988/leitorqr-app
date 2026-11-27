import SwiftUI
import UIKit

/// 全局设计令牌（design tokens）。
/// 页面里禁止硬编码颜色 / 圆角 / 间距 / 动画参数，一律从这里取，保证浅色与深色模式一致。
///
/// 配色体系「Sapphire Ink + Signal Mint」（2026-11-27 重设计）：
/// - 宝石蓝只负责**交互**（按钮、选中、链接）；
/// - 薄荷绿只表示**安全 / 成功**，琥珀只表示**待核对**，红只表示**风险**；
/// - 中性色带一点冷调，和玻璃材质、宝石蓝更协调。
/// 正文用色在对应背景上对比度均 ≥ 4.5:1；`success` 只做填充和图标，文字用 `successText`。
enum Theme {

    // MARK: - 颜色
    enum Palette {
        // 品牌
        /// 文字、图标、选中态。白底约 5.9:1，深底约 7.3:1。
        static let primary = Color(light: 0x2A52F0, dark: 0x7C9BFF)
        /// 作为**填充背景**使用的主色（按钮底、徽标底）。
        /// 与 `primary` 分开：`primary` 在深色模式下是提亮的蓝（给文字/图标用），
        /// 拿它当按钮底色会让白字对比不足，所以填充场景固定在深蓝一档。
        static let primaryFill = Color(light: 0x2449E6, dark: 0x3D63F5)
        /// 选中芯片、图标底的浅色铺底。
        static let primarySoft = Color(light: 0x2A52F0, dark: 0x7C9BFF).opacity(0.13)

        // 中性
        static let background = Color(light: 0xF4F6FB, dark: 0x0B0E14)
        static let surface = Color(light: 0xFFFFFF, dark: 0x151A23)
        static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x1D2330)
        /// 输入框、分段控件、图标按钮的凹陷底。
        static let surfaceSunken = Color(light: 0xEEF1F8, dark: 0x0F131B)
        static let textPrimary = Color(light: 0x0E1320, dark: 0xF2F4F8)
        static let textSecondary = Color(light: 0x5B6478, dark: 0x98A2B3)
        static let border = Color(light: 0xE3E7EF, dark: 0x2A3140)

        // 语义
        /// 安全 / 成功：只做填充和图标。
        static let success = Color(light: 0x19C37D, dark: 0x34D399)
        /// 安全判定的文字色（`success` 直接当文字对比不足）。
        static let successText = Color(light: 0x0B7F50, dark: 0x4ADE9B)
        static let warning = Color(light: 0xB45309, dark: 0xF5B544)
        static let error = Color(light: 0xD92D20, dark: 0xF97066)

        // 功能层
        /// 玻璃边缘高光（iOS 17–25 的 material 兜底方案用；iOS 26 由系统 glassEffect 自带）。
        static let glassEdge = Color.white.opacity(0.28)
        /// 扫描页取景框外遮罩，两种模式都用半透明黑，保证取景区域对比度。
        static let scannerScrim = Color.black.opacity(0.45)
        /// 摄像头预览的底色（深色恒定），不可用时不至于闪白。
        static let cameraBackdrop = Color(hex: 0x07090D)
        /// 命中瞬间取景框的锁定色。压在实时画面上，固定用亮一档的薄荷绿。
        static let scanLock = Color(hex: 0x34D399)
        /// 手电筒开启态。
        static let torch = Color(hex: 0xFFD54A)
    }

    // MARK: - 间距（基础单位 4pt）
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40

        /// 页面左右安全边距
        static let pageMargin: CGFloat = 20
    }

    // MARK: - 圆角
    enum Radius {
        static let card: CGFloat = 18
        static let button: CGFloat = 14
        static let field: CGFloat = 14
        static let chip: CGFloat = 10
        static let sheet: CGFloat = 24
    }

    // MARK: - 字体（全部基于系统文本样式，自动支持 Dynamic Type）
    enum Typography {
        static let pageTitle = Font.system(.title, design: .default).weight(.bold)
        static let sectionTitle = Font.system(.title3, design: .default).weight(.semibold)
        static let cardTitle = Font.system(.headline, design: .default)
        static let body = Font.system(.body, design: .default)
        static let bodyEmphasis = Font.system(.body, design: .default).weight(.semibold)
        static let caption = Font.system(.footnote, design: .default)
        static let mono = Font.system(.footnote, design: .monospaced)
        static let button = Font.system(.body, design: .default).weight(.semibold)
        /// 结果页的「实际域名」：等宽大字，quishing 防护的核心就是让人看清真实目标。
        static let domain = Font.system(.title3, design: .monospaced).weight(.semibold)
    }

    // MARK: - 动效
    /// 页面里**禁止**直接写 `.easeOut(duration:)` / `.spring(...)` 字面量，一律引用这里。
    /// 规则：所有动画只播放一次；不使用 `repeatForever`（扫描线、呼吸光、脉冲都不要）。
    enum Motion {
        /// 按压、开关、芯片选中、分段滑块。
        static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.86)
        /// 面板展开、布局变化、元素入场。
        static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.9)
        /// 只用于「成功」的一次性回弹（扫码锁定、保存成功）。
        static let success = Animation.spring(response: 0.36, dampingFraction: 0.72)
        /// 淡入淡出。
        static let fade = Animation.easeOut(duration: 0.18)
        /// 「画」一条线（判定环、进度）：先快后慢，收尾很柔。
        static let draw = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 0.7)
        /// 圆形揭开（换样式时新码从中心「长」出来）：快速起步、长长的柔和收尾。
        static let reveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.65)

        /// 减弱动态效果时统一降级为短淡入淡出。
        static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.15) : animation
        }
    }

    // MARK: - 其他
    enum Layout {
        static let hairline: CGFloat = 1
        static let iconSize: CGFloat = 20
        static let minTapTarget: CGFloat = 44
    }
}

// MARK: - 内容类型色板

/// 12 种内容类型一类一个颜色。只出现在 15% 浅底的图标块里，
/// 不做按钮、不做大面积填充，避免和品牌蓝、风险色抢语义。
extension ScanContentType {
    var tint: Color {
        switch self {
        case .url: return Color(light: 0x2A52F0, dark: 0x7C9BFF)
        case .text: return Color(light: 0x667085, dark: 0x98A2B3)
        case .wifi: return Color(light: 0x0B8BD0, dark: 0x36BFFA)
        case .email: return Color(light: 0xD4359F, dark: 0xF472D0)
        case .phone: return Color(light: 0x0E9F5C, dark: 0x32D583)
        case .sms: return Color(light: 0x0894B8, dark: 0x22CCEE)
        case .contact: return Color(light: 0x6941F0, dark: 0x9B8AFB)
        case .location: return Color(light: 0xE0372B, dark: 0xF97066)
        case .barcode: return Color(light: 0x344054, dark: 0xB4BCCB)
        case .event: return Color(light: 0xDC7A05, dark: 0xFDB022)
        case .payment: return Color(light: 0x08834A, dark: 0x3CCB7F)
        case .crypto: return Color(light: 0xC45E04, dark: 0xF79009)
        }
    }
}

/// 类型图标块：15% 类型色底 + 类型色图标。历史列表、结果页头部、多码列表共用。
struct ContentTypeBadge: View {
    let type: ScanContentType
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(type.tint)
            .frame(width: size, height: size)
            .background(
                type.tint.opacity(0.15),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - 统一按压反馈

/// 按下缩到 0.96，松手弹回。给卡片、图标按钮这类「非系统按钮」用，
/// 让全 App 的按压手感一致。
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

extension AnyTransition {
    /// 卡片 / 行插入：下移 12pt 淡入；移除：缩到 0.96 淡出。
    static var lift: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 12).combined(with: .opacity),
            removal: .scale(scale: 0.96).combined(with: .opacity)
        )
    }
}
