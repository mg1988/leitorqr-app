import PhotosUI
import SwiftUI
import UIKit

/// 样式面板实时预览需要的输入。由创建表单在主线程备好（中心图标是 SwiftUI 渲染的，只能在主线程画），
/// 真正的出图交给后台线程。
struct StylePreviewInput {
    let value: String
    let kind: BarcodeKind
    let style: QRCodeStyle
    let logo: UIImage?
}

/// 二维码样式面板：成套模板 + 分类网格 + 手动微调。
///
/// 交互规范：
/// 1. **草稿式编辑**：面板内仅修改 `draftStyle`，点击「应用」才写回外层；「取消」连中心图标一起回滚。
/// 2. **不卡主线程**（2026-11-27）：模板图 3x 约 2800px，之前 13 张缩略图在 `onAppear` 里同步渲染，
///    打开面板要卡一下；预览也在每次点选时同步重画。现在两者都在后台线程渲染：
///    缩略图逐张出图、逐张淡入，并按 ID 缓存到进程内存，第二次打开直接出图；
///    预览快速连点时只保留最后一次。
/// 3. **视觉**：分类芯片的选中块 matchedGeometry 滑动；卡片选中描边与对勾弹入；
///    PRO 角标统一成品牌蓝胶囊。不用任何渐变（11-27 用户要求），背景交给系统 sheet。
struct CodeStyleSheet: View {

    @Binding var style: QRCodeStyle
    /// 用户导入的中心图标。图片本身不进 `QRCodeStyle`——那个结构要能比较、能当 key。
    @Binding var customLogo: UIImage?
    /// 换图时自增，驱动预览重算。
    @Binding var logoVersion: Int
    let kind: BarcodeKind
    /// 是否有品牌图标可放（只有内容类型才有）。
    let brandLogoAvailable: Bool
    /// 用当前草稿样式备好一份预览输入；内容还不合法时返回 nil，面板退回示例内容。
    let makePreviewInput: (QRCodeStyle) -> StylePreviewInput?

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var chipNamespace
    @Namespace private var shapeNamespace

    @State private var draftStyle: QRCodeStyle
    /// 中心图标写在 binding 上（预览需要实时反映），取消时回滚到进入面板前的值。
    @State private var originalLogo: UIImage?
    @State private var originalLogoVersion: Int
    @State private var preview: UIImage?
    /// 每出一张新预览自增，驱动交叉淡入。
    @State private var previewVersion = 0
    @State private var previewTask: Task<Void, Never>?
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var thumbnailTask: Task<Void, Never>?
    @State private var category: CodeTemplateCategory = .all
    @State private var showManual: Bool
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickerFailed = false
    @State private var didApply = false

    private let sampleValue = "https://exemplo.pt"
    private let noneTemplateKey = "__none__"

    init(
        style: Binding<QRCodeStyle>,
        customLogo: Binding<UIImage?>,
        logoVersion: Binding<Int>,
        kind: BarcodeKind,
        brandLogoAvailable: Bool,
        makePreviewInput: @escaping (QRCodeStyle) -> StylePreviewInput?
    ) {
        self._style = style
        self._customLogo = customLogo
        self._logoVersion = logoVersion
        self.kind = kind
        self.brandLogoAvailable = brandLogoAvailable
        self.makePreviewInput = makePreviewInput
        self._draftStyle = State(initialValue: style.wrappedValue)
        self._originalLogo = State(initialValue: customLogo.wrappedValue)
        self._originalLogoVersion = State(initialValue: logoVersion.wrappedValue)
        // 条形码没有模板可挑，进来就直接给手动选项，别让用户多开一层。
        self._showManual = State(initialValue: kind != .qr)
    }

    private var supportsDotShape: Bool { kind == .qr }
    private var supportsTemplates: Bool { kind == .qr }

    /// 可选的图标来源。自由输入/条形码没有品牌图标，只剩"不放"和"我的图片"。
    private var logoOptions: [LogoSource] {
        brandLogoAvailable ? [.none, .brand, .custom] : [.none, .custom]
    }

    private var visibleTemplates: [CodeTemplate] {
        CodeTemplate.inCategory(category)
    }

    private var previewBackdrop: Color {
        draftStyle.template?.canvasColor ?? draftStyle.background
    }

    private var currentStyleName: String {
        draftStyle.template?.name ?? (draftStyle.templateID == nil ? L10n.Templates.none : L10n.Templates.custom)
    }

    /// 草稿里用了 PRO 权益、但还没买断。11-27 起不再拦截：可以应用、在创建页随便预览，
    /// 只在保存 / 分享时才弹付费墙；这里只用来显示一行说明。
    private var draftNeedsPro: Bool {
        !subscriptions.isPremium && draftStyle.usesPremiumFeatures
    }

    private func motion(_ animation: Animation) -> Animation {
        Theme.Motion.resolve(animation, reduceMotion: reduceMotion)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.s)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        previewBlock

                        if supportsTemplates {
                            templateSection
                        }

                        manualSection
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: draftStyle)
        .sensoryFeedback(.selection, trigger: category)
        .sensoryFeedback(.success, trigger: didApply) { _, new in new }
        .onAppear {
            refreshPreview()
            buildThumbnails()
        }
        .onDisappear {
            previewTask?.cancel()
            thumbnailTask?.cancel()
        }
        .onChange(of: draftStyle) { _, _ in refreshPreview() }
        .onChange(of: logoVersion) { _, _ in refreshPreview() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loadPickedImage(item)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                // 草稿式：换过的中心图标在取消时一并回滚，
                // 否则「取消」只撤销了样式，外层预览已经变成新图。
                customLogo = originalLogo
                logoVersion = originalLogoVersion + 1
                dismiss()
            } label: {
                Text(L10n.Common.cancel)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .glassSurface(.capsule, interactive: true)
            }
            .buttonStyle(PressableButtonStyle())

            Spacer(minLength: Theme.Spacing.xs)

            VStack(spacing: 2) {
                Text(L10n.Templates.title)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text(currentStyleName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(motion(Theme.Motion.fade), value: currentStyleName)
            }

            Spacer(minLength: Theme.Spacing.xs)

            Button(action: apply) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text(L10n.Templates.apply)
                        .font(Theme.Typography.button)
                        .contentTransition(.opacity)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule(style: .continuous).fill(Theme.Palette.primaryFill))
                .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .animation(motion(Theme.Motion.snappy), value: draftNeedsPro)
        }
    }

    private func apply() {
        style = draftStyle
        didApply = true
        dismiss()
    }

    // MARK: - 实时预览展台

    private var previewBlock: some View {
        VStack(spacing: Theme.Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(previewBackdrop)

                if let preview {
                    Image(uiImage: preview)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(Theme.Spacing.m)
                        .id(previewVersion)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    QRCodePlaceholderMark(size: 54)
                        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.35))
                }
            }
            .frame(height: 236)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                Text(currentStyleName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.opacity)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .glassSurface(.capsule)
                    .padding(.bottom, 10)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 9)
            .animation(motion(Theme.Motion.smooth), value: draftStyle.templateID)
            .animation(motion(Theme.Motion.smooth), value: draftStyle.backgroundHex)

            if draftNeedsPro {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.primary)
                    Text(L10n.Create.styleProHint)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.lift)
            }

            if draftStyle.isLowContrast {
                HStack(spacing: 6) {
                    WarningTriangleMark(size: 14)
                        .foregroundStyle(Theme.Palette.warning)

                    Text(L10n.Create.styleLowContrast)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.Palette.warning.opacity(0.12)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.lift)
            }
        }
        .animation(motion(Theme.Motion.smooth), value: draftStyle.isLowContrast)
        .animation(motion(Theme.Motion.smooth), value: draftNeedsPro)
    }

    // MARK: - 模板分类 + 网格

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionTitle(L10n.Templates.title)

            // 前置说明：带 PRO 角标的是 PRO 模板，让用户先看懂价值再决定点不点。
            if !subscriptions.isPremium {
                HStack(spacing: 6) {
                    proBadge
                    Text(L10n.Paywall.templateHint)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(CodeTemplateCategory.allCases) { item in
                        categoryChip(item)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.horizontal, -Theme.Spacing.pageMargin)
            .scrollClipDisabled()

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.s),
                    GridItem(.flexible(), spacing: Theme.Spacing.s)
                ],
                spacing: Theme.Spacing.s
            ) {
                if category == .all {
                    noneCard
                        .transition(.lift)
                }
                ForEach(visibleTemplates) { template in
                    templateCard(template)
                        .transition(.lift)
                }
            }
            .animation(motion(Theme.Motion.smooth), value: category)
        }
    }

    private func categoryChip(_ item: CodeTemplateCategory) -> some View {
        let isSelected = category == item
        return Button {
            guard category != item else { return }
            withAnimation(motion(Theme.Motion.snappy)) {
                category = item
            }
        } label: {
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Theme.Palette.background : Theme.Palette.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.Palette.textPrimary)
                            .matchedGeometryEffect(id: "category.selection", in: chipNamespace)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Theme.Palette.surface)
                            .overlay(Capsule(style: .continuous).strokeBorder(Theme.Palette.border, lineWidth: 1))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 「不用模板」卡片
    private var noneCard: some View {
        let isSelected = draftStyle.templateID == nil
        return Button {
            guard !isSelected else { return }
            withAnimation(motion(Theme.Motion.snappy)) {
                draftStyle.templateID = nil
            }
        } label: {
            cardBody(
                image: thumbnails[noneTemplateKey],
                title: L10n.Templates.none,
                categoryName: L10n.Templates.defaultCategory,
                backdrop: Color.white,
                isSelected: isSelected
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func templateCard(_ template: CodeTemplate) -> some View {
        let isSelected = draftStyle.templateID == template.id
        return Button {
            // 先试后买：PRO 模板可以直接选、直接预览，保存 / 分享时才需要买断。
            guard !isSelected else { return }
            withAnimation(motion(Theme.Motion.snappy)) {
                draftStyle = template.applying(to: draftStyle)
            }
        } label: {
            cardBody(
                image: thumbnails[template.id],
                title: template.name,
                categoryName: template.category.title,
                backdrop: template.canvasColor,
                isSelected: isSelected,
                isPremium: template.isPremium
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func cardBody(
        image: UIImage?,
        title: String,
        categoryName: String?,
        backdrop: Color,
        isSelected: Bool,
        isPremium: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                backdrop

                if let image {
                    Image(uiImage: image)
                        .interpolation(.medium)
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                        .transition(.opacity)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if isPremium && !subscriptions.isPremium {
                    proBadge.padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.Palette.primaryFill))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .padding(6)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let categoryName {
                    Text(categoryName)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 3)
            .padding(.bottom, 2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    isSelected ? Theme.Palette.primary : Theme.Palette.border,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .animation(motion(Theme.Motion.snappy), value: isSelected)
        .animation(motion(Theme.Motion.fade), value: image != nil)
    }

    /// PRO 角标：品牌蓝胶囊，和付费墙、安全中心同一款。
    private var proBadge: some View {
        Text(L10n.Paywall.proBadge)
            .font(.system(size: 9.5, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Theme.Palette.primaryFill))
    }

    // MARK: - 手动微调

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if supportsTemplates {
                Button {
                    withAnimation(motion(Theme.Motion.smooth)) { showManual.toggle() }
                } label: {
                    HStack {
                        sectionTitle(L10n.Templates.manual)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .rotationEffect(.degrees(showManual ? 0 : -90))
                    }
                    .frame(minHeight: Theme.Layout.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if showManual {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if supportsTemplates {
                        Text(L10n.Templates.adjustHint)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if supportsDotShape {
                        shapeSection
                        eyeSection
                    }
                    foregroundSection
                    backgroundSection
                    if supportsDotShape {
                        logoSection
                    }
                }
                .transition(.lift)
            }
        }
    }

    // MARK: - 点形状

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle(L10n.Create.styleShape)

            // 7 种形状一行放不下：4 列网格。
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs), count: 4), spacing: Theme.Spacing.xs) {
                ForEach(DotShape.allCases) { shape in
                    shapeChip(shape)
                }
            }
        }
    }

    private func shapeChip(_ shape: DotShape) -> some View {
        let isSelected = draftStyle.dotShape == shape
        return Button {
            guard draftStyle.dotShape != shape else { return }
            withAnimation(motion(Theme.Motion.snappy)) {
                draftStyle.dotShape = shape
            }
        } label: {
            VStack(spacing: 6) {
                DotShapeSample(shape: shape, color: isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
                    .frame(height: 18)

                HStack(spacing: 2) {
                    if shape.isPremium && !subscriptions.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                    }
                    Text(shape.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                            .strokeBorder(Theme.Palette.border, lineWidth: 1)
                    )
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                        .fill(Theme.Palette.primarySoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                                .strokeBorder(Theme.Palette.primary, lineWidth: 1.5)
                        )
                        .matchedGeometryEffect(id: "shape.selection", in: shapeNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 定位角

    private var eyeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle(L10n.Create.styleEyes)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs), count: 5), spacing: Theme.Spacing.xs) {
                ForEach(EyeShape.allCases) { eye in
                    eyeChip(eye)
                }
            }
        }
    }

    private func eyeChip(_ eye: EyeShape) -> some View {
        let isSelected = draftStyle.resolvedEyeShape == eye
        return Button {
            guard !isSelected else { return }
            withAnimation(motion(Theme.Motion.snappy)) {
                draftStyle.eyeShape = eye
                // 手动选外框形状：内块跟着外框走，不保留精选样式里的内块形状。
                draftStyle.eyeBallShape = nil
            }
        } label: {
            VStack(spacing: 6) {
                EyeShapeSample(shape: eye, color: isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
                    .frame(width: 22, height: 22)

                HStack(spacing: 2) {
                    if eye.isPremium && !subscriptions.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                    }
                    Text(eye.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                            .strokeBorder(Theme.Palette.border, lineWidth: 1)
                    )
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                        .fill(Theme.Palette.primarySoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                                .strokeBorder(Theme.Palette.primary, lineWidth: 1.5)
                        )
                        .matchedGeometryEffect(id: "eye.selection", in: shapeNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 颜色

    private var foregroundLabel: String {
        supportsDotShape ? L10n.Create.styleForeground : L10n.Create.styleBars
    }

    private var foregroundSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle(foregroundLabel)

            WrapLayout(spacing: Theme.Spacing.s, lineSpacing: Theme.Spacing.s) {
                ForEach(QRCodeStyle.foregroundSwatches, id: \.self) { hex in
                    swatch(hex: hex, isSelected: draftStyle.foregroundHex == hex) {
                        draftStyle.foregroundHex = hex
                        // 手动换码色时，定位角跟着换，不保留精选样式的强调色。
                        draftStyle.eyeHex = nil
                        draftStyle.eyeBallHex = nil
                    }
                }
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle(L10n.Create.styleBackground)

            WrapLayout(spacing: Theme.Spacing.s, lineSpacing: Theme.Spacing.s) {
                ForEach(QRCodeStyle.backgroundSwatches, id: \.self) { hex in
                    swatch(hex: hex, isSelected: draftStyle.backgroundHex == hex) {
                        draftStyle.backgroundHex = hex
                    }
                }
            }
        }
    }

    private func swatch(hex: UInt32, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !isSelected else { return }
            withAnimation(motion(Theme.Motion.snappy)) { action() }
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                .padding(4)
                .overlay(
                    Circle()
                        .strokeBorder(Theme.Palette.primary, lineWidth: 2)
                        .scaleEffect(isSelected ? 1 : 0.7)
                        .opacity(isSelected ? 1 : 0)
                )
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 中心图标

    private var logoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle(L10n.Create.styleLogo)

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(logoOptions) { option in
                    logoChip(option)
                }
            }

            if draftStyle.logoSource == .custom {
                customLogoRow
                    .transition(.lift)
            }

            if pickerFailed {
                Text(L10n.Create.logoUnavailable)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.error)
            }

            Text(L10n.Create.styleLogoHint)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Palette.border, lineWidth: 1)
        )
        .animation(motion(Theme.Motion.smooth), value: draftStyle.logoSource)
    }

    private func logoChip(_ option: LogoSource) -> some View {
        let isSelected = draftStyle.logoSource == option
        return Button {
            guard draftStyle.logoSource != option else { return }
            // 先试后买：自定义 Logo 也可以先放上去看效果，保存时再解锁。
            withAnimation(motion(Theme.Motion.snappy)) {
                draftStyle.logoSource = option
            }
        } label: {
            VStack(spacing: 5) {
                if option == .custom, draftStyle.logoSource == .custom, let customLogo {
                    Image(uiImage: customLogo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                } else {
                    logoOptionMark(for: option)
                        .frame(width: 18, height: 18)
                }

                Text(option.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .fill(isSelected ? Theme.Palette.primarySoft : Theme.Palette.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.Palette.primary : Theme.Palette.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if option == .custom && !subscriptions.isPremium {
                    proBadge.padding(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func logoOptionMark(for option: LogoSource) -> some View {
        switch option {
        case .none:
            SlashCircleMark(size: 18)
        case .brand:
            BadgeAppMark(size: 18)
        case .custom:
            PhotoMark(size: 18)
        }
    }

    /// 选图 / 换图 / 移除
    private var customLogoRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 6) {
                    PhotoBadgePlusMark(size: 16)
                    Text(customLogo == nil ? L10n.Create.logoPick : L10n.Create.logoReplace)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.primary)
                .padding(.horizontal, Theme.Spacing.s)
                .frame(height: 34)
                .background(Theme.Palette.primarySoft, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())

            Spacer(minLength: 0)

            if customLogo != nil {
                Button {
                    withAnimation(motion(Theme.Motion.smooth)) {
                        customLogo = nil
                        pickerItem = nil
                        logoVersion += 1
                    }
                } label: {
                    Text(L10n.Create.logoRemove)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.error)
                        .frame(minHeight: Theme.Layout.minTapTarget)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem) {
        pickerFailed = false
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            guard let data, let image = UIImage(data: data) else {
                await MainActor.run { pickerFailed = true }
                return
            }
            let scaled = image.scaledDown(to: 512)
            await MainActor.run {
                withAnimation(motion(Theme.Motion.smooth)) {
                    customLogo = scaled
                    logoVersion += 1
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
    }

    // MARK: - 后台出图

    /// 预览：主线程只备输入（中心图标），渲染放到后台；快速连点时只保留最后一次。
    private func refreshPreview() {
        previewTask?.cancel()
        let input = makePreviewInput(draftStyle)
            ?? StylePreviewInput(value: sampleValue, kind: kind, style: draftStyle, logo: nil)
        previewTask = Task { @MainActor in
            let rendered = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let image = try? BarcodeImageGenerator.render(
                    value: input.value,
                    kind: input.kind,
                    style: input.style,
                    logo: input.logo
                ) else { return nil }
                return image.scaledDown(to: 1024)
            }.value
            guard !Task.isCancelled else { return }
            withAnimation(motion(Theme.Motion.fade)) {
                preview = rendered
                previewVersion += 1
            }
        }
    }

    /// 网格缩略图：先用缓存，缺的在后台逐张渲染、逐张淡入。
    private func buildThumbnails() {
        guard supportsTemplates else { return }
        thumbnails = StyleThumbnailCache.images

        let noneKey = noneTemplateKey
        let pending = ([noneKey] + CodeTemplate.all.map(\.id)).filter { thumbnails[$0] == nil }
        guard !pending.isEmpty else { return }
        let sample = sampleValue

        thumbnailTask?.cancel()
        thumbnailTask = Task { @MainActor in
            for id in pending {
                guard !Task.isCancelled else { return }
                let image = await Task.detached(priority: .utility) { () -> UIImage? in
                    let style = id == noneKey
                        ? QRCodeStyle()
                        : (CodeTemplate.withID(id)?.previewStyle ?? QRCodeStyle())
                    guard let full = try? BarcodeImageGenerator.render(
                        value: sample,
                        kind: .qr,
                        style: style
                    ) else { return nil }
                    // 2 列网格单卡约 170pt，@3x 512px 足够；再大只会多占内存。
                    return full.scaledDown(to: 512)
                }.value
                guard let image, !Task.isCancelled else { continue }
                StyleThumbnailCache.images[id] = image
                thumbnails[id] = image
            }
        }
    }
}

/// 样式面板模板缩略图的进程内缓存：示例内容固定，图只和模板有关，第二次打开面板直接出图。
/// 只在主线程读写（见调用处），不加 actor 标注，免得 struct 属性初始化 / 非隔离方法里访问报错。
private enum StyleThumbnailCache {
    static var images: [String: UIImage] = [:]
}

/// 一个 4×3 的点阵小样，按当前形状与颜色画出来——直接展示"点了会变成什么样"。
private struct DotShapeSample: View {

    let shape: DotShape
    let color: Color

    private let side: CGFloat = 8
    private let gap: CGFloat = 2.4

    var body: some View {
        switch shape {
        case .fluid:
            // 横向连成一片的三行
            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(color).frame(width: side * 4 + gap * 3, height: side)
                }
            }
        case .bars:
            // 竖向连成一根的四列
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(color).frame(width: side * 0.82, height: side * 3 + gap * 2)
                }
            }
        default:
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: gap) {
                        ForEach(0..<3, id: \.self) { _ in
                            module
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var module: some View {
        switch shape {
        case .square:
            Rectangle().fill(color).frame(width: side, height: side)
        case .rounded:
            RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                .fill(color)
                .frame(width: side, height: side)
        case .circle, .fluid, .bars:
            Circle().fill(color).frame(width: side, height: side)
        case .dots:
            Circle().fill(color).frame(width: side * 0.72, height: side * 0.72)
                .frame(width: side, height: side)
        case .classy:
            UnevenRoundedRectangle(
                topLeadingRadius: side * 0.48,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: side * 0.48,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(color)
            .frame(width: side, height: side)
        }
    }
}

/// 定位角小样：外框 + 内块，形状和码里画出来的一致。
private struct EyeShapeSample: View {
    let shape: EyeShape
    let color: Color

    var body: some View {
        ZStack {
            outline(inset: 0)
                .stroke(color, lineWidth: 3)
                .padding(1.5)
            outline(inset: 7)
                .fill(color)
                .padding(7)
        }
    }

    private func outline(inset: CGFloat) -> AnyShape {
        let scale: CGFloat = inset > 0 ? 0.45 : 1
        switch shape {
        case .square:
            return AnyShape(Rectangle())
        case .rounded:
            return AnyShape(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous))
        case .circle:
            return AnyShape(Circle())
        case .drop:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 9 * scale,
                bottomLeadingRadius: 9 * scale,
                bottomTrailingRadius: 1.5 * scale,
                topTrailingRadius: 9 * scale,
                style: .continuous
            ))
        case .leaf:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 9 * scale,
                bottomLeadingRadius: 1.5 * scale,
                bottomTrailingRadius: 9 * scale,
                topTrailingRadius: 1.5 * scale,
                style: .continuous
            ))
        }
    }
}

#Preview {
    CodeStyleSheet(
        style: .constant(QRCodeStyle()),
        customLogo: .constant(nil),
        logoVersion: .constant(0),
        kind: .qr,
        brandLogoAvailable: true,
        makePreviewInput: { _ in nil }
    )
    .environmentObject(SubscriptionManager())
}

extension UIImage {
    /// 等比缩到最长边不超过 `maxSide`，小图原样返回。
    func scaledDown(to maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
