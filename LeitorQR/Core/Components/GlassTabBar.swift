import SwiftUI
import UIKit

/// 底栏高度上报。RootTabView 用它给各 Tab 页面留出底部空间。
struct TabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 底栏占用的底部高度环境变量（UITabBarController 原生接管 safe area，默认 0）。
private struct TabBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarInset: CGFloat {
        get { self[TabBarInsetKey.self] }
        set { self[TabBarInsetKey.self] = newValue }
    }
}

extension View {
    /// 方案 A（UITabBarController 接管）：
    /// 系统原生 UITabBar 会自动计算并下发底部 safeAreaInsets，ScrollView 与 List
    /// 自然停靠并支持穿透底栏折射，不再需要手动插入空白占位。
    func floatingTabBarInset() -> some View {
        self
    }
}

/// 方案 A：Telegram / Apple 原生级全宽贴底液态玻璃底栏（Edge-to-Edge Liquid Glass TabBar）
///
/// 核心工业设计：
/// 1. **全宽贴底（Edge-to-Edge）**：
///    完全抛弃浮动胶囊孤岛，屏幕从左到右 100% 铺满，背景穿透 Home Indicator 直达屏幕最底端。
/// 2. **原生大面积超薄折射毛玻璃（.ultraThinMaterial）**：
///    页面内容向下滚动时，整片底部 83pt 区域呈现大面积、细腻、丝滑的高透光折射，与 Telegram 完全一致。
/// 3. **0.33pt 视网膜级顶边发丝线（Hairline Divider）**：
///    顶边仅保留 0.33pt 极细微反光线，极致内敛，区分内容与功能底栏。
/// 4. **纯正 Apple 原生极简交互（无多余肥皂块）**：
///    选中 Tab 呈现饱满品牌色（或扫描深色底下的纯白），带自然微弹缩放与轻柔触感反馈。
struct GlassTabBar: View {

    @Binding var selection: RootTabView.Tab
    /// 底栏背后是否为深色画面（如扫描页摄像头画面）。
    var overDarkBackdrop: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabs = RootTabView.Tab.allCases
    private let barInteractiveHeight: CGFloat = 49

    var body: some View {
        VStack(spacing: 0) {
            // 顶边 0.33pt 极细发丝分隔线（Telegram 标配）
            hairlineDivider

            // 4 个 Tab 交互单元
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }
            }
            .frame(height: barInteractiveHeight)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .background {
            // 全屏大面积液态毛玻璃底衬（连同底部安全区一并铺满）
            liquidGlassBackdrop
        }
        // 连续拖拽手势：依然支持在底栏上按住横滑实时切换 Tab
        .gesture(dragGesture)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: TabBarHeightKey.self, value: proxy.size.height)
            }
        }
    }

    // MARK: - 顶边 0.33pt 发丝分割线

    private var hairlineDivider: some View {
        Rectangle()
            .fill(
                overDarkBackdrop
                    ? Color.white.opacity(0.16)
                    : Color.black.opacity(0.10)
            )
            .frame(height: 0.33)
    }

    // MARK: - 全屏贴底液态毛玻璃底衬（贯穿 Home Indicator）

    private var liquidGlassBackdrop: some View {
        ZStack {
            // A. 原生超薄折射材质
            Rectangle()
                .fill(.ultraThinMaterial)

            // B. 极简微洗色（透出底层色彩，绝不发灰发糊）
            Rectangle()
                .fill(
                    overDarkBackdrop
                        ? Color.black.opacity(0.15)
                        : Color.white.opacity(0.35)
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Tab 项单元（点击即切换，带轻触感）

    private func tabButton(_ tab: RootTabView.Tab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                selection = tab
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        } label: {
            // spacing 4 而不是 3：泰语/印地语的字形上伸部分更高，
            // 3pt 时文字会贴到图标下沿。
            VStack(spacing: 4) {
                tabIcon(for: tab, isSelected: isSelected)
                    .frame(height: 22)
                    .scaleEffect(isSelected ? 1.08 : 1.0)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(
                isSelected
                    ? (overDarkBackdrop ? Color.white : Theme.Palette.primary)
                    : (overDarkBackdrop ? Color.white.opacity(0.55) : Theme.Palette.textSecondary)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 连续跟手拖拽手势（支持按住底栏横向滑动切换）

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let totalWidth = UIScreen.main.bounds.width
                let slotWidth = totalWidth / CGFloat(tabs.count)
                let rawIndex = Int(value.location.x / slotWidth)
                let targetIndex = max(0, min(rawIndex, tabs.count - 1))
                let targetTab = tabs[targetIndex]

                if selection != targetTab {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                        selection = targetTab
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    // MARK: - 纯矢量 Tab 图标

    @ViewBuilder
    private func tabIcon(for tab: RootTabView.Tab, isSelected: Bool) -> some View {
        switch tab {
        case .scan:
            TabScanMark(isSelected: isSelected)
        case .create:
            TabCreateMark(isSelected: isSelected)
        case .history:
            TabHistoryMark(isSelected: isSelected)
        case .settings:
            TabSettingsMark(isSelected: isSelected)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        GlassTabBar(selection: .constant(.history))
    }
    .background(Theme.Palette.background)
}
