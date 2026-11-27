import SwiftData
import SwiftUI

/// 创建首页。
///
/// 2026-11-27 重设计：
/// - 顶部新增「最近创建」横向卡片（自己生成过的码，最多 8 条），点一下用 Zoom 转场直接打开详情，
///   重复用的码（店内 Wi-Fi、菜单、名片）一步到位；没有生成记录时整段不出现。
/// - 内容类型与条形码改用「类型色浅底 + 类型色图标」的软磁贴，颜色与历史、结果页同一套类型色板；
///   社交平台保留品牌色磁贴（品牌识别靠的就是那块颜色）。
/// - 分区卡片改为不透明 surface + 细描边，背景去掉紫色光斑，只留一层品牌蓝。
/// - 所有入口都是 Zoom 转场（iOS 18+），返回时缩回原位置。
/// - 11-27：Hero 广告卡片移到最顶上（3D 翻页 + 视差 + 自动播放进度条，见 `CreateHeroCarouselView`），
///   「最近创建」在它下面；悬浮添加按钮改为原生液态玻璃。
struct CreateLandingView: View {

    @Environment(\.tabBarInset) private var tabBarInset
    @Namespace private var heroNamespace

    @State private var destination: CreateMode?
    /// Zoom 转场从哪个视图放大：Hero 卡片和下面的磁贴是同一个 mode，但来源不同。
    @State private var zoomSourceID: String?
    @State private var showingCustom = false
    /// 仅 Debug：截图时直接进某个入口。
    @State private var didApplyDebugRoute = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // 顶部 Hero 广告卡片：横向 3D 翻页 + 视差，贴到屏幕边缘。
                        CreateHeroCarouselView(namespace: heroNamespace) { mode in
                            open(mode, source: CreateHeroCarouselView.sourceID(for: mode))
                        }
                        .padding(.horizontal, -Theme.Spacing.pageMargin)

                        // 社交平台：品牌色磁贴
                        section(title: L10n.Create.sectionSocial) {
                            ForEach(CreateType.social) { type in
                                CreateAppIconTile(
                                    title: type.title,
                                    tint: type.tint,
                                    action: { open(.type(type)) }
                                ) {
                                    BrandMark(type: type, size: 24)
                                }
                                .heroTransitionSource(id: type.heroID, in: heroNamespace)
                            }
                        }

                        // 二维码内容类型：类型色软磁贴
                        section(title: L10n.Create.sectionQR) {
                            ForEach(CreateType.others) { type in
                                CreateSoftTile(
                                    title: type.title,
                                    tint: type.contentTint,
                                    action: { open(.type(type)) }
                                ) {
                                    BrandMark(type: type, size: 24)
                                }
                                .heroTransitionSource(id: type.heroID, in: heroNamespace)
                            }
                        }

                        // 条形码制
                        section(title: L10n.Create.sectionBarcode) {
                            ForEach(BarcodeKind.oneDimensional) { kind in
                                CreateSoftTile(
                                    title: kind.title,
                                    tint: ScanContentType.barcode.tint,
                                    action: { open(.barcode(kind)) }
                                ) {
                                    BarcodeMark(kind: kind, size: 26)
                                }
                                .heroTransitionSource(id: kind.heroID, in: heroNamespace)
                            }
                        }
                        .id("barcode_section")
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.xs)
                }
                // 给右下角悬浮按钮留出空间：最后一行能滚到按钮上方，不会一直被盖住。
                .contentMargins(.bottom, 88, for: .scrollContent)
                .background(CreateScreenBackground())
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    #if DEBUG
                    if DebugLaunchOptions.createScrollBottom {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(Theme.Motion.smooth) {
                                proxy.scrollTo("barcode_section", anchor: .bottom)
                            }
                        }
                    }
                    #endif
                }
            }
            .navigationTitle(L10n.Create.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProCrownButton()
                }
            }
            .overlay(alignment: .bottomTrailing) { addButton }
            .navigationDestination(item: $destination) { mode in
                destinationView(for: mode)
            }
            .sheet(isPresented: $showingCustom) {
                NavigationStack {
                    CreateFormView(mode: .custom)
                        .environment(\.tabBarInset, 0)
                        .toolbar {
                            // 右上角是「生成」，关闭放左上角。
                            ToolbarItem(placement: .topBarLeading) {
                                Button(L10n.Common.close) { showingCustom = false }
                            }
                        }
                }
            }
            .onAppear(perform: applyDebugRoute)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    // MARK: - 目标页面（含 iOS 18+ Zoom 转场）

    @ViewBuilder
    private func destinationView(for mode: CreateMode) -> some View {
        if #available(iOS 18.0, *) {
            CreateFormView(mode: mode)
                .navigationTransition(.zoom(sourceID: zoomSourceID ?? mode.heroID, in: heroNamespace))
        } else {
            CreateFormView(mode: mode)
        }
    }

    // MARK: - 分区

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.leading, 2)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 16
            ) {
                content()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
    }

    // MARK: - 悬浮添加

    private var addButton: some View {
        Button {
            showingCustom = true
        } label: {
            PlusMark(size: 22)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .modifier(FloatingAddStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: showingCustom) { _, new in new }
        .accessibilityLabel(L10n.Create.add)
        .padding(.trailing, Theme.Spacing.pageMargin)
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - 行为

    /// 打开某个创建表单。`source` 指定 Zoom 转场的来源视图，默认是同名磁贴。
    private func open(_ mode: CreateMode, source: String? = nil) {
        zoomSourceID = source
        destination = mode
    }

    /// 仅 Debug：`LEITORQR_CREATE_TYPE=wifi` 直接打开对应表单，方便截图验收。
    private func applyDebugRoute() {
        #if DEBUG
        guard !didApplyDebugRoute else { return }
        didApplyDebugRoute = true
        if let raw = DebugLaunchOptions.createType {
            if let type = CreateType(rawValue: raw) {
                destination = .type(type)
            } else if let kind = BarcodeKind(rawValue: raw) {
                destination = .barcode(kind)
            }
            return
        }
        if DebugLaunchOptions.customForm {
            showingCustom = true
            return
        }
        // 兼容旧的截图参数：预填内容 + 直接进网站类型。
        if DebugLaunchOptions.prefillGenerator != nil {
            destination = .type(.website)
        }
        #endif
    }
}

/// 右下角悬浮添加按钮：iOS 26 用系统 `.glassProminent` 圆形（品牌蓝液态玻璃）；低版本实心圆。
private struct FloatingAddStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(Theme.Palette.primaryFill)
        } else {
            content
                .padding(11)
                .background(Circle().fill(Theme.Palette.primaryFill))
                .shadow(color: Theme.Palette.primaryFill.opacity(0.3), radius: 14, y: 6)
                .buttonStyle(PressableButtonStyle(scale: 0.9))
        }
    }
}

// MARK: - 类型色映射

extension CreateType {
    /// 内容类型对应的「类型色」，与历史 / 结果页的 `ScanContentType.tint` 一致。
    /// 社交平台继续用品牌色（`tint`）。
    var contentTint: Color {
        switch self {
        case .website: return ScanContentType.url.tint
        case .text: return ScanContentType.text.tint
        case .email: return ScanContentType.email.tint
        case .sms: return ScanContentType.sms.tint
        case .phone: return ScanContentType.phone.tint
        case .wifi: return ScanContentType.wifi.tint
        case .contact: return ScanContentType.contact.tint
        case .location: return ScanContentType.location.tint
        default: return tint
        }
    }
}

// MARK: - 单个入口

/// 图标 + 名称，没有容器：白底卡片铺开会像一张表格，把图标的重量稀释掉。
/// 靠网格间距分组比靠容器分组更轻。
struct CreateEntryTile<Mark: View>: View {

    let title: String
    let tint: Color
    let action: () -> Void
    @ViewBuilder let mark: () -> Mark

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(tint.opacity(0.12))
                    mark()
                        .foregroundStyle(tint)
                }
                .frame(width: 44, height: 44)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }
            .frame(maxWidth: .infinity)
            // 没有容器兜底，点击区域要自己撑满整格，否则只能点中图标。
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(title)
    }
}

/// 按压：轻微缩小，不做花哨效果。保留给旧调用点，新代码用 `PressableButtonStyle`。
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Hero 转场辅助

extension View {
    @ViewBuilder
    func heroTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

#Preview {
    CreateLandingView()
        .environmentObject(SubscriptionManager())
        .environment(\.tabBarInset, 74)
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
