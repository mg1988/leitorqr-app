import StoreKit
import SwiftUI
import UIKit

/// 付费墙 —— **只卖一次性买断**（2026-11-27 体验卡下架），无订阅、无试用。
///
/// 2026-11-27 重设计：先让用户看到价值，再说价格。
/// - 顶部是三张**真实渲染**的 PRO 模板码（扇形展开一次），替换低对比度的灰色液态背景图；
/// - 权益从一行 12pt 灰字恢复成 2×2 图标清单；
/// - 只有一档：权益下面是一张买断说明卡（名称 + 「一次付费，永久使用」+ 价格），CTA「立即买断 · 价格」；
/// - 商品没拉到时价格显示「–」并禁用 CTA（不编造价格，Guideline 3.1）；
/// - 进场按 hero → 标题 → 权益 → 方案 → CTA 依次淡入上移，**只播一次**，减弱动态效果时只淡入。
///
/// 布局约束（踩过两轮，别动）：
/// 1. 背景必须 `.background { }`，不能作 ZStack 子视图——带 ignoresSafeArea 的背景
///    会把 ZStack 撑到 434pt，整组居中后两侧 20pt 边距被挤成 4pt。
/// 2. 不用 ScrollView：内容一屏放得下，纵向 ScrollView 给内容的宽度 proposal 不稳定。
///    小屏靠 hero 的弹性高度（84–132pt）吸收差额。
/// 3. 标题卡 22pt + lineLimit(1)：葡语 31 字在 25pt 下要 370pt，可用只有 362pt。
struct PaywallView: View {

    var showsCloseButton: Bool = true
    var triggerReason: PaywallTriggerManager.TriggerReason? = nil
    /// 嵌在别的页面里（首次启动引导的最后一步）时由外面处理关闭；参数 = 是否刚买完。
    /// nil = 作为 fullScreenCover 呈现，走 PaywallTriggerManager + dismiss。
    var onClose: ((_ purchased: Bool) -> Void)? = nil

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isRestoring = false
    @State private var presentedLegalDoc: LegalDocumentType? = nil
    @State private var showOfferCodeSheet = false
    /// 进场动画只播一次。
    @State private var appeared = false

    private var lifetimePrice: String? {
        subscriptions.product(id: SubscriptionManager.lifetimeProductID)?.displayPrice
    }

    /// 商品没加载出来（离线 / StoreKit 未就绪）时不显示虚构的兜底价：
    /// 各 storefront 实际价格不同，硬编码 € 价可能被审核认定误导（Guideline 3.1）。
    private var priceNote: String {
        guard let price = lifetimePrice else { return L10n.Paywall.priceNotePending }
        return String(format: L10n.Paywall.priceNoteLifetime, price)
    }

    private var isPurchasing: Bool { subscriptions.purchaseState == .purchasing }
    /// 商品没拉到时 CTA 仍可点：点了先重拉商品，拿不到再提示（不再整颗变灰）。
    @State private var isRetryingProducts = false
    @State private var showUnavailable = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, Theme.Spacing.xs)

            // 多出来的高度**拆成两段**：上面这段封顶 96pt，剩下的留给买断卡上方。
            // 只留一个 Spacer 时，6.3" 上会把 ~200pt 全堆在权益和买断卡之间，
            // 上半截挤成一坨、下半截空一大块（实测 92 / 105 最均衡）。
            // 用 maxHeight 而不是固定高度：小屏余量不足时自动压回去，4.7" 不受影响。
            Spacer(minLength: 0).frame(maxHeight: 96)

            PaywallTemplateFan(isRevealed: appeared, reduceMotion: reduceMotion)
                .frame(minHeight: 84, idealHeight: 132, maxHeight: 132)
                .padding(.top, Theme.Spacing.xs)
                .entrance(0, appeared: appeared, reduceMotion: reduceMotion)

            heroHeader
                .padding(.top, Theme.Spacing.m)
                .entrance(1, appeared: appeared, reduceMotion: reduceMotion)

            benefitGrid
                .padding(.top, Theme.Spacing.l)
                .entrance(2, appeared: appeared, reduceMotion: reduceMotion)

            Spacer(minLength: Theme.Spacing.l)

            // 已经是会员（重装后恢复了买断、测试环境里买过）：原地换成「已解锁」，由用户点「继续」离开，
            // 不自动关闭、不显示购买按钮。
            Group {
                if showsUnlocked {
                    unlockedCard
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    offerCard
                        .transition(.opacity)
                }
            }
            .entrance(3, appeared: appeared, reduceMotion: reduceMotion)

            Group {
                if showsUnlocked {
                    unlockedBar
                        .transition(.opacity)
                } else {
                    bottomBar
                        .transition(.opacity)
                }
            }
            .padding(.top, Theme.Spacing.m)
            .entrance(4, appeared: appeared, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.bottom, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop }
        .navigationBarHidden(true)
        .animation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion), value: showsUnlocked)
        .sensoryFeedback(.success, trigger: showsUnlocked) { old, new in !old && new }
        .sensoryFeedback(.success, trigger: subscriptions.purchaseState) { _, new in new == .success }
        .onAppear {
            guard !appeared else { return }
            withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
        .task {
            if !subscriptions.hasLoadedProduct {
                await subscriptions.refresh()
            }
        }
        .onChange(of: subscriptions.purchaseState) { _, state in
            if state == .success { close(purchased: true) }
        }
        .sheet(item: $presentedLegalDoc) { doc in
            NavigationStack {
                LegalDocumentView(type: doc, isModal: true)
            }
        }
        .offerCodeRedemption(isPresented: $showOfferCodeSheet)
    }

    // MARK: - 背景

    /// 纯色页面底（不用渐变）。
    private var backdrop: some View {
        Theme.Palette.background
            .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                isRestoring = true
                Task { @MainActor in
                    await subscriptions.restorePurchases()
                    isRestoring = false
                }
            } label: {
                ZStack {
                    Text(L10n.Settings.restore)
                        .opacity(isRestoring ? 0 : 1)
                    if isRestoring {
                        ProgressView().controlSize(.small)
                    }
                }
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.primary)
                .padding(.horizontal, 14)
                .frame(height: 34)
            }
            .modifier(PaywallGlassButton(shape: .capsule))
            .disabled(isRestoring)

            Spacer()

            if showsCloseButton {
                // 11-27「要点很多次才关掉」：原来是在按钮的 label 上套 `.glassEffect(.interactive())`，
                // iOS 26 上可交互玻璃会自己吃掉触摸（按压形变），Button 经常收不到点击；
                // 而且点击区只有 34pt，低于 44pt。现在用系统 `.buttonStyle(.glass)`（点击和玻璃反馈都由系统处理），
                // 点击区补到 44pt。
                Button {
                    close(purchased: false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: 34, height: 34)
                }
                .modifier(PaywallGlassButton(shape: .circle))
                .accessibilityLabel(L10n.Common.close)
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func close(purchased: Bool) {
        if let onClose {
            onClose(purchased)
            return
        }
        if purchased {
            PaywallTriggerManager.shared.dismissWithoutCooldown()
        } else {
            PaywallTriggerManager.shared.recordDismiss()
        }
        dismiss()
    }

    // MARK: - 标题（情境化）

    /// 标题贴着用户刚发生的动作：扫码后讲「保存这次扫描」，历史满讲「历史已满」，
    /// 模板/Logo 这类主动点击讲「解锁高级样式」。冷启动与设置入口用默认标题。
    private var heroTitle: String {
        guard let triggerReason else { return L10n.Paywall.title }
        switch triggerReason {
        case .postAha:
            return L10n.Paywall.contextScanTitle
        case .usageLimit:
            return L10n.Paywall.contextLimitTitle
        case .featureGate:
            return L10n.Paywall.contextFeatureTitle
        case .onboarding:
            return L10n.Paywall.contextOnboardingTitle
        case .coldLaunch, .direct:
            return L10n.Paywall.title
        }
    }

    /// 权益已经有独立清单，副标题只在情境化时补一句「为什么现在」；默认态用通用副标题
    /// （「一次付费，永久使用」写在下面的买断卡里，这里不重复）。
    private var heroSubtitle: String {
        guard let triggerReason else { return L10n.Paywall.subtitle }
        switch triggerReason {
        case .postAha:
            return L10n.Paywall.contextScanSubtitle
        case .usageLimit:
            return L10n.Paywall.contextLimitSubtitle
        case .featureGate:
            return L10n.Paywall.contextFeatureSubtitle
        case .onboarding:
            return L10n.Paywall.contextOnboardingSubtitle
        case .coldLaunch, .direct:
            return L10n.Paywall.subtitle
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 6) {
            Text(heroTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 权益 2×2

    private var benefitGrid: some View {
        let items: [(String, String)] = [
            ("infinity", L10n.Paywall.benefitHistory),
            ("paintpalette.fill", L10n.Paywall.benefitTemplates),
            ("photo.badge.plus", L10n.Paywall.benefitCustom),
            ("checkmark.shield.fill", L10n.Paywall.benefitSecurity)
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(items.indices, id: \.self) { index in
                let icon = items[index].0
                let title = items[index].1
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Theme.Palette.primarySoft,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - 买断说明卡

    /// 只有一档，不再是可选列表：一张静态卡写清「是什么、多少钱、付几次」。
    private var offerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "infinity")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Theme.Palette.primaryFill,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Paywall.planLifetime)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(L10n.Paywall.planLifetimeNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 6)

            Text(lifetimePrice ?? "–")
                .font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText())
                .layoutPriority(1)
                .animation(Theme.Motion.smooth, value: lifetimePrice)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Palette.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.primary.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 已解锁

    /// 刚买完时 purchaseState == .success，页面马上就会关掉，不用切成「已解锁」再闪一下。
    private var showsUnlocked: Bool {
        subscriptions.isPremium && subscriptions.purchaseState != .success
    }

    private var unlockedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Theme.Palette.success,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Paywall.unlockedTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subscriptions.snapshot.isLifetime ? L10n.Settings.cardLifetimeDetail : subscriptions.snapshot.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Palette.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.success.opacity(0.45), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }

    private var unlockedBar: some View {
        VStack(spacing: 10) {
            Button {
                close(purchased: true)
            } label: {
                Text(L10n.Paywall.unlockedContinue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(PrimaryButtonStyle())

            legalFooter
        }
    }

    // MARK: - 底部：CTA + 价格披露 + 法律链接

    private var ctaTitle: String {
        guard let price = lifetimePrice else { return L10n.Paywall.ctaBuy }
        return "\(L10n.Paywall.ctaBuy) · \(price)"
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    if lifetimePrice == nil {
                        isRetryingProducts = true
                        await subscriptions.refresh()
                        isRetryingProducts = false
                    }
                    guard subscriptions.product(id: SubscriptionManager.lifetimeProductID) != nil else {
                        withAnimation(Theme.Motion.fade) { showUnavailable = true }
                        return
                    }
                    showUnavailable = false
                    await subscriptions.purchase(id: SubscriptionManager.lifetimeProductID)
                }
            } label: {
                ZStack {
                    Text(ctaTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .opacity(isPurchasing || isRetryingProducts ? 0 : 1)
                    if isPurchasing || isRetryingProducts {
                        ProgressView().tint(.white)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .allowsHitTesting(!isPurchasing && !isRetryingProducts)
            .sensoryFeedback(.impact(weight: .medium), trigger: isPurchasing) { _, new in new }
            .animation(Theme.Motion.snappy, value: ctaTitle)
            .animation(Theme.Motion.fade, value: isPurchasing)

            Group {
                if showUnavailable {
                    Text(L10n.Subscription.unavailable)
                        .foregroundStyle(Theme.Palette.error)
                } else if case .failed = subscriptions.purchaseState {
                    Text(L10n.Paywall.purchaseFailed)
                        .foregroundStyle(Theme.Palette.error)
                } else if subscriptions.purchaseState == .pending {
                    Text(L10n.Paywall.purchasePending)
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    Text(priceNote)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .font(.system(size: 11.5))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)

            legalFooter
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 10) {
            Button { presentedLegalDoc = .terms } label: { Text(L10n.Settings.terms) }
            Text("·")
            Button { showOfferCodeSheet = true } label: { Text(L10n.Paywall.redeemCode) }
            Text("·")
            Button { presentedLegalDoc = .privacy } label: { Text(L10n.Settings.privacy) }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.Palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 进场

private extension View {
    /// 依次淡入上移。每项间隔 50ms，只在 `appeared` 由 false → true 时播放一次。
    func entrance(_ index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(
                Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)
                    .delay(reduceMotion ? 0 : Double(index) * 0.05),
                value: appeared
            )
    }
}

// MARK: - 模板扇面

/// 三张真实渲染的 PRO 模板码，进场时从叠放状态扇形展开一次。
///
/// 渲染很贵（模板 3x 画布约 2800px），所以：后台线程画、缩到 360px、按 ID 缓存在内存里；
/// 画好之前先显示模板画布色的占位卡，不闪白。
private struct PaywallTemplateFan: View {
    var isRevealed: Bool
    var reduceMotion: Bool

    /// 左 / 中 / 右。都是 PRO 模板，色相拉开。
    private static let templateIDs = ["social-sunset", "love-heart", "birthday-balloons"]

    @State private var images: [String: UIImage] = PaywallTemplateCache.images

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.height - 8, 112)
            ZStack {
                ForEach(Array(Self.templateIDs.enumerated()), id: \.element) { index, id in
                    card(id: id, side: side)
                        .rotationEffect(.degrees(isRevealed && !reduceMotion ? angle(index) : 0))
                        .offset(
                            x: isRevealed ? offsetX(index, side: side) : 0,
                            y: isRevealed && index != 1 ? side * 0.06 : 0
                        )
                        .zIndex(index == 1 ? 1 : 0)
                        .animation(
                            Theme.Motion.resolve(Theme.Motion.success, reduceMotion: reduceMotion)
                                .delay(reduceMotion ? 0 : 0.08),
                            value: isRevealed
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
        .task { await loadIfNeeded() }
    }

    private func angle(_ index: Int) -> Double {
        [-9, 0, 9][index]
    }

    private func offsetX(_ index: Int, side: CGFloat) -> CGFloat {
        [-side * 0.82, 0, side * 0.82][index]
    }

    @ViewBuilder
    private func card(id: String, side: CGFloat) -> some View {
        let template = CodeTemplate.withID(id)
        Group {
            if let image = images[id] {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                (template?.canvasColor ?? Theme.Palette.surfaceSunken)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
        .animation(Theme.Motion.fade, value: images[id] != nil)
    }

    private func loadIfNeeded() async {
        let missing = Self.templateIDs.filter { images[$0] == nil }
        guard !missing.isEmpty else { return }
        let value = SubscriptionManager.showcaseCodeValue
        let rendered = await Task.detached(priority: .userInitiated) { () -> [String: UIImage] in
            var result: [String: UIImage] = [:]
            for id in missing {
                guard let template = CodeTemplate.withID(id),
                      let image = try? BarcodeImageGenerator.render(
                        value: value,
                        kind: .qr,
                        style: template.previewStyle
                      ) else { continue }
                result[id] = image.scaledDown(to: 360)
            }
            return result
        }.value
        PaywallTemplateCache.images.merge(rendered) { _, new in new }
        images = PaywallTemplateCache.images
    }
}

/// 付费墙模板图的进程内缓存：第二次打开付费墙直接出图，不再重画。
/// 只在主线程读写，不加 actor 标注：`@State` 的默认值初始化处于非隔离上下文。
private enum PaywallTemplateCache {
    static var images: [String: UIImage] = [:]
}

#Preview {
    NavigationStack {
        PaywallView()
            .environmentObject(SubscriptionManager())
    }
}

/// 付费墙顶栏的两个小玻璃钮（恢复购买 / 关闭）。
/// iOS 26：系统 `.glass` 按钮样式；低版本：材质底 + 细描边。两种情况点击区都不小于 44pt。
private struct PaywallGlassButton: ViewModifier {
    enum Shape { case capsule, circle }
    let shape: Shape

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .frame(minHeight: 44)
            case .circle:
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .frame(minWidth: 44, minHeight: 44)
            }
        } else {
            switch shape {
            case .capsule:
                content
                    .glassSurface(.capsule)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())
            case .circle:
                content
                    .glassSurface(.circle)
                    .padding(5)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
            }
        }
    }
}

