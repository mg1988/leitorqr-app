import SwiftUI

/// 各页签右上角的 PRO 皇冠入口。
///
/// 未订阅时皇冠压暗，点了进付费墙；已订阅时皇冠保持原色并带主色底，
/// 点了进订阅管理（可在那里取消订阅、查看下次续费日）。
/// 具体路由交给 `ProPortal`——付费墙在全项目只有根视图一处呈现。
struct ProCrownButton: View {

    /// 导航栏里用浅色圆底；相机画面压在实时视频上，用深色玻璃圆钮。
    enum Style {
        case navigation
        case glass
    }

    var style: Style = .navigation
    /// 皇冠可见宽度（玻璃圆钮内部会自动居中）。
    var crownWidth: CGFloat = 24

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @ObservedObject private var portal = ProPortal.shared

    private var isPremium: Bool { subscriptions.isPremium }

    var body: some View {
        Button {
            portal.openCrown(isPremium: isPremium)
        } label: {
            switch style {
            case .navigation:
                // iOS 26+ 的 toolbar 已经自动给 Button 一份圆形玻璃底；再自己画一层
                // fill + strokeBorder 就成了两个同心圆（实测截图很明显）。低版本没有
                // 自动底，才自己做一份，保持同一套控件观感。
                if #available(iOS 26.0, *) {
                    crown
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                } else {
                    crown
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(navigationFill))
                        .overlay(Circle().strokeBorder(navigationBorder, lineWidth: 0.5))
                }
            case .glass:
                crown
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .glassSurface(.circle, tone: .dark, interactive: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Pro.entry)
        .accessibilityValue(isPremium ? L10n.Pro.active : L10n.Pro.inactive)
    }

    private var crown: some View {
        Image("ProCrown")
            .resizable()
            .scaledToFit()
            .frame(width: crownWidth)
            // 金属银本身是浅色，未订阅时降透明度表示「未解锁」。
            // 但相机页的深色玻璃本身就有对比，再压一层只会显脏。
            .opacity(isPremium || style == .glass || navigationIsGlass ? 1 : 0.72)
    }

    /// iOS 26+ 系统玻璃底自带对比，皇冠不需要再压暗一层。
    private var navigationIsGlass: Bool {
        if #available(iOS 26.0, *) { return style == .navigation }
        return false
    }

    private var navigationFill: Color {
        isPremium ? Theme.Palette.primary.opacity(0.18) : Theme.Palette.primary.opacity(0.08)
    }

    private var navigationBorder: Color {
        isPremium ? Theme.Palette.primary.opacity(0.3) : Theme.Palette.primary.opacity(0.12)
    }
}
