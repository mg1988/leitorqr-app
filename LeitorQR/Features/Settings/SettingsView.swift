import SwiftUI

/// 设置页。
///
/// 2026-11-27 重设计：
/// - 每一行前面是 iOS 设置风格的**彩色图标块**（29pt 圆角方块 + 白色图标），颜色沿用类型色板，
///   一眼就能在长列表里定位；同一语义同一颜色（Wi-Fi = Wi-Fi 类型色，网址 = 网址类型色）。
/// - 外观从分段控件改成三张**迷你界面预览卡**（浅色 / 深色 / 跟随系统），选中描边用
///   matchedGeometryEffect 滑动，切换时整页颜色平滑过渡。
/// - 开关统一用品牌蓝（绿色只表示「安全」，不拿来当开关色）。
/// - 顶部是**会员卡片**（11-27 用户要求替换品牌横幅；第三版：液态玻璃二维码插画背景，配色取自插画），
///   按权益状态显示「立即买断」「体验卡剩余天数 + 升级」（体验卡已下架，只给已购用户）「已永久解锁」。
///   价格只来自 StoreKit；拿不到时显示「–」并禁用购买。**没有免费试用**，卡片上不写「试用」。
/// - 右上角 PRO 皇冠只在卡片滚出屏幕后出现（卡片可见时它是重复入口）。
struct SettingsView: View {

    /// 外观模式：跟随系统、浅色、深色
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    /// 识别提示音开关
    @AppStorage(ScanFeedback.soundEnabledKey) private var scanSoundEnabled = true

    /// 扫描后自动处理（三个独立开关，默认关闭）
    @AppStorage(ScanAutoActionSettings.wifiAutoConnectKey)
    private var wifiAutoConnect = ScanAutoActionSettings.wifiAutoConnectDefault
    @AppStorage(ScanAutoActionSettings.websiteAutoOpenKey)
    private var websiteAutoOpen = ScanAutoActionSettings.websiteAutoOpenDefault
    @AppStorage(ScanAutoActionSettings.linkAutoOpenKey)
    private var linkAutoOpen = ScanAutoActionSettings.linkAutoOpenDefault

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 会员卡片是否还在屏幕上。滚出导航栏下沿后，右上角才出现 PRO 皇冠。
    @State private var isCardVisible = true

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 0. 会员卡片
                // 放在一个**没有行的 Section 的 header** 里，而不是作为列表行：
                // insetGrouped 的行总会被系统包一层圆角分组底（iOS 26 上 listRowBackground(.clear)
                // 也盖不掉），卡片外面就多出一层卡片。header 没有分组底，卡片就是唯一的一层。
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        MembershipCard()
                            .onGeometryChange(for: Bool.self) { proxy in
                                // 卡片底边还在导航栏下沿（约 120pt）以下，就算「看得见」。
                                proxy.frame(in: .global).maxY > 120
                            } action: { visible in
                                guard visible != isCardVisible else { return }
                                withAnimation(Theme.Motion.resolve(Theme.Motion.snappy, reduceMotion: reduceMotion)) {
                                    isCardVisible = visible
                                }
                            }

                        if let disclosure = priceDisclosure {
                            Text(disclosure)
                                .font(.footnote)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, Theme.Spacing.xs)
                        }
                    }
                    .textCase(nil)
                    // header 默认有左右内边距和字体样式；这里清零，卡片和下面分组同宽。
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
                }

                // MARK: - 1. 安全防护（基础提示免费，历史/白名单/批量为 PRO）
                Section {
                    NavigationLink {
                        SecurityCenterView()
                    } label: {
                        SettingsRowLabel(
                            title: L10n.Security.title,
                            systemImage: "checkmark.shield.fill",
                            tint: Theme.Palette.successText
                        )
                    }
                } header: {
                    Text(L10n.Security.sectionTitle)
                } footer: {
                    Text(L10n.Security.settingsFooter)
                }

                // MARK: - 2. 扫描后自动处理（三个开关相互独立）
                Section {
                    autoToggle(
                        isOn: $wifiAutoConnect,
                        title: L10n.Settings.autoWifi,
                        detail: L10n.Settings.autoWifiDesc,
                        systemImage: "wifi",
                        tint: ScanContentType.wifi.tint
                    )
                    autoToggle(
                        isOn: $websiteAutoOpen,
                        title: L10n.Settings.autoWebsite,
                        detail: L10n.Settings.autoWebsiteDesc,
                        systemImage: "safari.fill",
                        tint: ScanContentType.url.tint
                    )
                    autoToggle(
                        isOn: $linkAutoOpen,
                        title: L10n.Settings.autoLink,
                        detail: L10n.Settings.autoLinkDesc,
                        systemImage: "phone.arrow.up.right.fill",
                        tint: ScanContentType.phone.tint
                    )
                } header: {
                    Text(L10n.Settings.sectionAutoAction)
                } footer: {
                    Text(L10n.Settings.autoActionFooter)
                }

                // MARK: - 3. 外观（三张迷你预览卡）
                Section {
                    AppearancePicker(selection: $appearanceRaw)
                        .listRowInsets(EdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 12))
                } header: {
                    Text(L10n.Settings.sectionAppearance)
                }

                // MARK: - 4. 通用（多语言与扫码反馈）
                Section {
                    NavigationLink {
                        LanguageSelectionView()
                    } label: {
                        SettingsRowLabel(
                            title: L10n.Settings.language,
                            systemImage: "globe",
                            tint: Theme.Palette.primaryFill,
                            value: LanguageManager.shared.displayName
                        )
                    }

                    Toggle(isOn: $scanSoundEnabled) {
                        SettingsRowLabel(
                            title: L10n.Settings.scanSound,
                            systemImage: scanSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                            tint: Color(light: 0xE0372B, dark: 0xF04438)
                        )
                    }
                    .tint(Theme.Palette.primaryFill)
                    .sensoryFeedback(.selection, trigger: scanSoundEnabled)
                } header: {
                    Text(L10n.Settings.sectionGeneral)
                } footer: {
                    Text(L10n.Settings.languageFooter)
                }

                // MARK: - 5. 法律条款与支持
                Section {
                    NavigationLink {
                        LegalDocumentView(type: .privacy, isModal: false)
                    } label: {
                        SettingsRowLabel(
                            title: L10n.Settings.privacy,
                            systemImage: "hand.raised.fill",
                            tint: Color(light: 0x475467, dark: 0x667085)
                        )
                    }

                    NavigationLink {
                        LegalDocumentView(type: .terms, isModal: false)
                    } label: {
                        SettingsRowLabel(
                            title: L10n.Settings.terms,
                            systemImage: "doc.text.fill",
                            tint: Color(light: 0x475467, dark: 0x667085)
                        )
                    }

                    Link(destination: SubscriptionManager.supportURL) {
                        HStack {
                            SettingsRowLabel(
                                title: L10n.Settings.support,
                                systemImage: "envelope.fill",
                                tint: ScanContentType.email.tint
                            )
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                } header: {
                    Text(L10n.Settings.sectionLegal)
                }

                // MARK: - 6. 关于
                Section {
                    HStack {
                        SettingsRowLabel(
                            title: L10n.Settings.version,
                            systemImage: "info",
                            tint: Color(light: 0x98A2B3, dark: 0x475467)
                        )
                        Spacer()
                        Text(versionText)
                            .font(Theme.Typography.body.monospacedDigit())
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                } header: {
                    Text(L10n.Settings.sectionAbout)
                } footer: {
                    Text(
                        [L10n.Settings.heroPrivacy,
                         L10n.Settings.heroNoAds,
                         L10n.Settings.heroOnDevice]
                            .joined(separator: " · ")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.s)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(L10n.Settings.title)
            // 卡片在屏幕上时它就是 PRO 入口；滚走以后右上角皇冠接替。
            .toolbar {
                if !isCardVisible {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProCrownButton()
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
        }
    }

    /// 带说明的自动处理开关。说明文字在标题下方，开关统一品牌蓝。
    private func autoToggle(
        isOn: Binding<Bool>,
        title: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                SettingsIcon(systemImage: systemImage, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.Palette.primaryFill)
        .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
        .padding(.vertical, 2)
    }

    /// 卡片下方的价格披露：未购买时写清「一次性、不续费」（审核 3.1 要求价格说明清晰）。
    private var priceDisclosure: String? {
        guard !subscriptions.isPremium else { return nil }
        guard let lifetime = subscriptions.product(id: SubscriptionManager.lifetimeProductID)?.displayPrice else {
            return L10n.Paywall.priceNotePending
        }
        return String(format: L10n.Paywall.priceNoteLifetime, lifetime)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - 会员卡片

/// 设置页顶部的会员卡片（11-27 第三版：插画方案 B）。
///
/// - 背景是液态玻璃二维码插画（`PremiumCardArt`）：浅色模式冰蓝、深色模式午夜蓝，由资源目录按外观自动切换。
///   插画在右侧；左侧用**插画本身的底色**做渐变遮罩，文字压在这块干净区域上。
///   卡片上所有颜色都取自插画——第一、二版另配的照片暗角 / 纯色蓝和页面其他颜色对不上。
/// - 内容：标题 + 一句话 + 三条打勾权益 → 整宽按钮。整张卡和按钮都只打开付费墙，不在这里直接购买。
/// - 已解锁（11-27 第四版）：不再用插画当背景——76pt 高的横条里 scaledToFill 会把插画裁得只剩一截。
///   改成纯文字会员卡：纯色底 + 皇冠徽标 + 标题 / 说明 + 底部三项已解锁权益。
///   （11-27 用户要求：卡上不放二维码。）
/// 价格只来自 StoreKit，拿不到时显示「–」并禁用购买。
private struct MembershipCard: View {

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 每次点卡片自增，只用来触发一次轻触感。
    @State private var tapCount = 0

    // 配色全部取自插画（浅色 = 冰蓝插画，深色 = 午夜蓝插画）。
    /// 插画左侧的底色，用作文字区遮罩。
    private static let artBase = Color(light: 0xE6F6FB, dark: 0x030E2B)
    private static let titleColor = Color(light: 0x0B1F3A, dark: 0xFFFFFF)
    private static let subtitleColor = Color(light: 0x3D5A73, dark: 0xB7C4DA)
    /// 对勾：浅色用品牌蓝，深色用薄荷绿（和扫码成功同色）。
    private static let checkColor = Color(light: 0x2A52F0, dark: 0x34D399)
    /// 购买按钮：浅色是品牌蓝底白字，深色是白底深蓝字。
    private static let buttonFill = Color(light: 0x2449E6, dark: 0xFFFFFF)
    private static let buttonText = Color(light: 0xFFFFFF, dark: 0x0B1F4D)
    private static let cornerRadius: CGFloat = 22
    /// 卡片细描边：浅色模式下冰蓝底和页面灰底很接近，靠它把卡片边界勾出来。
    private static let cardStroke = Color(light: 0xCFE6EF, dark: 0x1B2A4A)
    /// 皇冠徽标的底色：品牌蓝 / 深色模式下的亮蓝，图标白色。
    private static let crownFill = Color(light: 0x2449E6, dark: 0x3D63F5)
    /// 已解锁卡片的入场（只播一次）。
    @State private var unlockedAppeared = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    private var snapshot: SubscriptionSnapshot { subscriptions.snapshot }

    private var lifetimePrice: String? {
        subscriptions.product(id: SubscriptionManager.lifetimeProductID)?.displayPrice
    }

    private enum Mode: Equatable {
        case free
        case weeklyPass(daysLeft: Int)
        case unlocked
    }

    private var mode: Mode {
        guard subscriptions.isPremium else { return .free }
        if snapshot.state == .weeklyPass, let expiry = snapshot.expirationDate {
            let days = Int(ceil(expiry.timeIntervalSinceNow / 86_400))
            return .weeklyPass(daysLeft: max(days, 1))
        }
        return .unlocked
    }

    var body: some View {
        Group {
            switch mode {
            case .free:
                offer(subtitle: L10n.Paywall.planLifetimeNote, buttonTitle: L10n.Paywall.ctaBuy)
                    .background(artBackground)
            case .weeklyPass(let days):
                offer(subtitle: L10n.Settings.cardDaysLeft(days), buttonTitle: L10n.Settings.cardUpgrade)
                    .background(artBackground)
            case .unlocked:
                unlocked
                    .background(Self.artBase)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Self.cardStroke, lineWidth: 1))
        .animation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion), value: mode)
    }

    // MARK: 未买断

    private func offer(subtitle: String, buttonTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openDetails) {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock(subtitle: subtitle)
                    checklist
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.98))

            Spacer(minLength: 16)

            buyButton(title: buttonTitle)
        }
        .padding(16)
        // 固定 214 会让长译文顶穿卡片；用最小高度保证视觉基线，内容多时自动长高。
        .frame(minHeight: 214)
    }

    private func titleBlock(subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "Leitor QR Premium")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Self.titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Self.subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(.numericText())
        }
    }

    /// 三条打勾的权益，只占左侧约 60%，右侧留给插画。
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            checkRow(L10n.Paywall.benefitHistory)
            checkRow(L10n.Paywall.benefitTemplates)
            checkRow(L10n.Paywall.benefitSecurity)
        }
        // 固定上限而不是按比例：List 行里 containerRelativeFrame 量的是整个列表，不是卡片。
        .frame(maxWidth: 220, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func checkRow(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Self.checkColor)
            // 泰语/芬兰语等长译文会超过 220pt，单行会被硬裁（连省略号都没有）；
            // 允许折到第二行，卡片高度随内容自适应。
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Self.titleColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 卡片上的按钮**只负责打开付费墙**（11-27 用户要求），不在设置页直接发起购买：
    /// 完整权益、价格披露、恢复购买、条款都在付费墙里，设置页只做入口。
    /// 按钮永远是实心可点的样子；价格拿到了就顺带显示，拿不到只显示标题。
    private func buyButton(title: String) -> some View {
        Button(action: openDetails) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let lifetimePrice {
                    Text(verbatim: "· \(lifetimePrice)")
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                        .transition(.opacity)
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 30)
            .contentShape(Capsule())
            .animation(Theme.Motion.fade, value: lifetimePrice)
        }
        .modifier(CardButtonStyle(fill: Self.buttonFill, text: Self.buttonText))
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    // MARK: 已解锁

    /// ```
    ///  [👑]  终身会员                                   ›
    ///        Leitor QR Premium
    ///        所有功能已永久解锁
    ///  ─────────────────────────────────────────
    ///  ✓ 无限历史      ✓ 全部样式      ✓ 安全检测
    /// ```
    /// 纯文字 + 一个皇冠徽标，所有元素都完整在卡内；不放二维码、不放插画。
    private var unlocked: some View {
        Button(action: openDetails) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    crownBadge

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.Settings.cardLifetimeBadge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Self.checkColor)
                            .lineLimit(1)

                        Text(verbatim: "Leitor QR Premium")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Self.titleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(L10n.Settings.cardLifetimeDetail)
                            .font(.footnote)
                            .foregroundStyle(Self.subtitleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Self.subtitleColor)
                }

                Rectangle()
                    .fill(Self.cardStroke)
                    .frame(height: 1)

                HStack(spacing: 0) {
                    perk(L10n.Settings.cardPerkHistory, index: 0)
                    Spacer(minLength: 8)
                    perk(L10n.Settings.cardPerkStyles, index: 1)
                    Spacer(minLength: 8)
                    perk(L10n.Settings.cardPerkSecurity, index: 2)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .task {
            guard !unlockedAppeared else { return }
            withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)) {
                unlockedAppeared = true
            }
        }
    }

    /// 左侧 52pt 圆角方块 + 白色皇冠，完整在卡内。入场时轻轻放大淡入一次。
    private var crownBadge: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Self.crownFill)
            .frame(width: 52, height: 52)
            .overlay {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(unlockedAppeared || reduceMotion ? 1 : 0.85)
            .opacity(unlockedAppeared ? 1 : 0)
            .accessibilityHidden(true)
    }

    /// 一项已解锁权益：对勾 + 短文字，纯文字不加底色胶囊。依次淡入（只播一次）。
    private func perk(_ title: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.checkColor)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Self.titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .opacity(unlockedAppeared ? 1 : 0)
        .offset(y: unlockedAppeared || reduceMotion ? 0 : 6)
        .animation(
            Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion).delay(0.12 + Double(index) * 0.06),
            value: unlockedAppeared
        )
    }

    // MARK: 背景

    /// 插画贴右侧铺满，不叠任何渐变遮罩：插画左侧本身就是大片干净的底色，文字直接压在上面。
    private var artBackground: some View {
        ZStack {
            Self.artBase
            Image("PremiumCardArt")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .clipped()
                .accessibilityHidden(true)
        }
    }

    private func openDetails() {
        tapCount += 1
        if subscriptions.isPremium {
            ProPortal.shared.isSubscriptionPresented = true
        } else {
            PaywallTriggerManager.shared.openFromSettings()
        }
    }
}

/// 会员卡片按钮：iOS 26 用系统 `.glassProminent`（染成卡片按钮色的液态玻璃）；低版本实心胶囊。
private struct CardButtonStyle: ViewModifier {
    let fill: Color
    let text: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(fill)
                .foregroundStyle(text)
        } else {
            content
                .foregroundStyle(text)
                .frame(height: 44)
                .background(fill, in: Capsule(style: .continuous))
                .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - 行组件

/// iOS 设置风格的彩色图标块：29pt 圆角方块 + 白色图标。
struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 29, height: 29)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 图标块 + 标题（+ 右侧取值）。给 NavigationLink / Toggle 当 label。
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var value: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            SettingsIcon(systemImage: systemImage, tint: tint)
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
            if let value {
                Spacer(minLength: Theme.Spacing.xs)
                Text(value)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 外观选择

/// 三张迷你界面预览卡：浅色 / 深色 / 跟随系统（左右各半）。
/// 选中描边用 matchedGeometryEffect 在卡片之间滑动；切换时整页颜色随之过渡。
private struct AppearancePicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    private let order: [AppAppearance] = [.light, .dark, .system]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(order) { item in
                let isSelected = selection == item.rawValue
                Button {
                    withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)) {
                        selection = item.rawValue
                    }
                } label: {
                    VStack(spacing: 8) {
                        AppearanceThumbnail(appearance: item)
                            .frame(height: 92)
                            .padding(3)
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Theme.Palette.primary, lineWidth: 2.5)
                                        .matchedGeometryEffect(id: "appearance.ring", in: namespace)
                                }
                            }

                        HStack(spacing: 4) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary.opacity(0.6))
                                .contentTransition(.symbolEffect(.replace))
                            Text(item.title)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.95))
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// 迷你界面：标题条 + 两张卡片 + 底部胶囊 Tab 栏。颜色写死为浅/深两套，不随当前外观变化。
private struct AppearanceThumbnail: View {
    let appearance: AppAppearance

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch appearance {
                case .light:
                    MiniScreen(isDark: false)
                case .dark:
                    MiniScreen(isDark: true)
                case .system:
                    HStack(spacing: 0) {
                        MiniScreen(isDark: false)
                            .frame(width: proxy.size.width, alignment: .leading)
                            .frame(width: proxy.size.width / 2, alignment: .leading)
                            .clipped()
                        MiniScreen(isDark: true)
                            .frame(width: proxy.size.width, alignment: .trailing)
                            .frame(width: proxy.size.width / 2, alignment: .trailing)
                            .clipped()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
    }
}

private struct MiniScreen: View {
    let isDark: Bool

    private var background: Color { Color(hex: isDark ? 0x0B0E14 : 0xF4F6FB) }
    private var surface: Color { Color(hex: isDark ? 0x1D2330 : 0xFFFFFF) }
    private var line: Color { Color(hex: isDark ? 0x2A3140 : 0xE3E7EF) }
    private var accent: Color { Color(hex: isDark ? 0x7C9BFF : 0x2A52F0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(line).frame(width: 28, height: 5)
                .padding(.top, 9)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(surface)
                .frame(height: 20)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 10, height: 10).padding(.leading, 5)
                }
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(surface)
                .frame(height: 20)
            Spacer(minLength: 0)
            Capsule()
                .fill(surface)
                .frame(height: 10)
                .overlay(Capsule().fill(accent).frame(width: 10, height: 4))
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
