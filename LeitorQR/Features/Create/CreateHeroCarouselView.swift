import SwiftUI

/// 创建页顶部的 Hero 广告卡片（2026-11-27 重构）。
///
/// 视觉：每张卡一种纯色底（不用任何渐变），左文右图：左边小标题 + 标题 + 说明 + 白色行动胶囊，
/// 右边一个透明底的 3D 液态玻璃插画。所有元素都完整在卡片内，不探出边缘。
///
/// 交互动画（全部基于 iOS 17 原生滚动 API，不用 TabView）：
/// 1. **3D 翻页**：`scrollTransition` —— 离开中心的卡片缩小、绕 Y 轴转 ±12°、变淡，像一叠卡片在转。
/// 2. **视差**：插画自己挂一层 `scrollTransition`，滑动时相对卡片轻微反向位移，静止时归零。
/// 3. **自动播放 + 进度条**：当前页的指示器从左到右填满（4.5 秒）后翻到下一张；
///    用户亲手滑过 / 点过指示器后不再自动播放，指示器保持填满。减弱动态效果时不自动播放、不做 3D。
/// 4. **入场**：首次出现时插画从上方轻轻落下、转正，文字从左滑入，只播一次。
/// 5. 点卡片用 Zoom 转场（iOS 18+）放大进入对应表单。
struct CreateHeroCarouselView: View {

    let namespace: Namespace.ID
    let onSelect: (CreateMode) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentID: Int? = 0
    @State private var userTookControl = false
    @State private var progress: CGFloat = 0
    @State private var appeared = false
    /// 自动播放刚改过页码的时间：这段时间内的页码变化不算「用户滑动」。
    @State private var lastProgrammaticChange = Date.distantPast
    @State private var userPageChanges = 0

    /// 卡片两侧留白；下一张卡会从右边露出一点。
    static let sideMargin: CGFloat = 20
    private static let interval: Double = 4.5

    private var autoplays: Bool { !userTookControl && !reduceMotion }

    static func sourceID(for mode: CreateMode) -> String { "hero_\(mode.heroID)" }

    private var items: [HeroItem] {
        [
            HeroItem(
                id: 0,
                mode: .type(.wifi),
                badge: L10n.Create.Carousel.badgePopular,
                title: L10n.Create.Carousel.titleWifi,
                subtitle: L10n.Create.Carousel.subtitleWifi,
                buttonText: L10n.Create.Carousel.buttonWifi,
                color: Color(hex: 0x0A72B8),
                art: "CreateHeroWiFi"
            ),
            HeroItem(
                id: 1,
                mode: .type(.instagram),
                badge: L10n.Create.Carousel.badgeSocial,
                title: L10n.Create.Carousel.titleInstagram,
                subtitle: L10n.Create.Carousel.subtitleInstagram,
                buttonText: L10n.Create.Carousel.buttonInstagram,
                color: Color(hex: 0xC92A62),
                art: "CreateHeroSocial"
            ),
            HeroItem(
                id: 2,
                mode: .type(.contact),
                badge: L10n.Create.Carousel.badgeBusiness,
                title: L10n.Create.Carousel.titleVCard,
                subtitle: L10n.Create.Carousel.subtitleVCard,
                buttonText: L10n.Create.Carousel.buttonVCard,
                color: Color(hex: 0x5B3BD9),
                art: "CreateHeroCard"
            ),
            HeroItem(
                id: 3,
                mode: .barcode(.ean13),
                badge: L10n.Create.Carousel.badgeRetail,
                title: L10n.Create.Carousel.titleEAN13,
                subtitle: L10n.Create.Carousel.subtitleEAN13,
                buttonText: L10n.Create.Carousel.buttonEAN13,
                color: Color(hex: 0x1D2939),
                art: "CreateHeroBarcode"
            )
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentID)
            .contentMargins(.horizontal, Self.sideMargin, for: .scrollContent)
            .scrollClipDisabled()
            .frame(height: HeroCard.height)

            indicator
        }
        .sensoryFeedback(.selection, trigger: userPageChanges)
        .onChange(of: currentID) { _, _ in
            // 自动播放刚翻过页：忽略这次变化（跨页回到第一张时滚动会经过中间几页）。
            guard Date().timeIntervalSince(lastProgrammaticChange) > 1 else { return }
            userTookControl = true
            userPageChanges += 1
        }
        .task(id: AutoplayKey(page: currentID, active: scenePhase == .active, autoplays: autoplays)) {
            await runAutoplayStep()
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(Theme.Motion.success.delay(0.12)) { appeared = true }
            }
        }
    }

    // MARK: - 卡片

    private func card(_ item: HeroItem) -> some View {
        Button {
            onSelect(item.mode)
        } label: {
            HeroCard(item: item, appeared: appeared, isCurrent: currentID == item.id)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
        .heroTransitionSource(id: Self.sourceID(for: item.mode), in: namespace)
        .containerRelativeFrame(.horizontal)
        .scrollTransition(.interactive, axis: .horizontal) { [reduceMotion] content, phase in
            content
                .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.08)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : phase.value * -12),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(1 - abs(phase.value) * 0.35)
        }
        .id(item.id)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 指示器

    /// 当前页是一段会被填满的胶囊（自动播放时随时间填满，用户接管后保持填满），其余是小圆点。点任意一段跳过去。
    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let isCurrent = currentID == item.id
                Button {
                    guard !isCurrent else { return }
                    userTookControl = true
                    userPageChanges += 1
                    withAnimation(Theme.Motion.smooth) { currentID = item.id }
                } label: {
                    Capsule()
                        .fill(Theme.Palette.textSecondary.opacity(0.22))
                        .frame(width: isCurrent ? 28 : 7, height: 7)
                        .overlay(alignment: .leading) {
                            if isCurrent {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(Theme.Palette.primary)
                                        .frame(width: max(7, proxy.size.width * (autoplays ? progress : 1)))
                                }
                            }
                        }
                        .frame(height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
        .animation(Theme.Motion.snappy, value: currentID)
    }

    // MARK: - 自动播放

    private func runAutoplayStep() async {
        guard autoplays, scenePhase == .active else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        // 让「归零」先落一帧，下面的线性动画才会从 0 开始。
        try? await Task.sleep(nanoseconds: 40_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: Self.interval)) { progress = 1 }
        try? await Task.sleep(nanoseconds: UInt64(Self.interval * 1_000_000_000))
        guard !Task.isCancelled, autoplays, scenePhase == .active else { return }
        let ids = items.map(\.id)
        let index = ids.firstIndex(of: currentID ?? 0) ?? 0
        lastProgrammaticChange = Date()
        withAnimation(Theme.Motion.smooth) {
            currentID = ids[(index + 1) % ids.count]
        }
    }
}

private struct AutoplayKey: Hashable {
    let page: Int?
    let active: Bool
    let autoplays: Bool
}

// MARK: - 单张卡片

private struct HeroItem: Identifiable {
    let id: Int
    let mode: CreateMode
    let badge: String
    let title: String
    let subtitle: String
    let buttonText: String
    let color: Color
    let art: String
}

private struct HeroCard: View {
    let item: HeroItem
    let appeared: Bool
    let isCurrent: Bool

    static let height: CGFloat = 196
    private static let radius: CGFloat = 26

    /// 左文右图的 HStack：插画有自己固定的位置，**不会再和文字重叠、也不会被卡片边缘裁掉**。
    /// （上一版用 ZStack 叠放，插画和斜放的二维码纹理故意探出卡片边缘，看起来像没显示全。）
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            content
                .offset(x: appeared ? 0 : -14)
                .opacity(appeared ? 1 : 0)

            Image(item.art)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 10)
                .scaleEffect(isCurrent ? 1 : 0.88)
                .rotationEffect(.degrees(appeared ? 0 : 10))
                .offset(y: appeared ? 0 : -18)
                .opacity(appeared ? 1 : 0)
                // 视差：插画按自己在滚动区里的位置轻微反向位移，静止时归零。
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content.offset(x: phase.value * -24)
                }
                .animation(Theme.Motion.success, value: isCurrent)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(item.color)
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 小标题：纯文字，不再是带底色的胶囊标签。
            Text(item.badge)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(item.title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            HStack(spacing: 4) {
                Text(item.buttonText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(item.color)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color.white, in: Capsule())
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
