import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 创建表单（11-27 第五版）：两步。
///
/// ```
///  第 1 步「填写内容」 CreateFormView        第 2 步「设计样式」 CreateStudioView
///  ┌──────────────────────┐              ┌──────────────────────┐
///  │ 〈  填写内容 ▬▬   [生成] │              │ 〈  设计样式 ▬▬    [↶] │  ↶ = 撤销
///  │ [图标] 大标题 / 说明     │    生成 →     │       [  QR  ]        │  轻点全屏出示
///  │ 输入框…                │              │   内容摘要 / PRO 提示    │
///  │ 备注                   │              ╭──────────────────────╮
///  │                        │              │ 精选 码点 码眼 颜色 图标 模板 │  左右滑也能切
///  │                        │              │ 选项网格（实时缩略图）      │  点一下立刻生效
///  └──────────────────────┘              │ ═ 保存 ═   ═ 分享 ═      │
///                                        ╰──────────────────────╯
/// ```
/// - 样式放在 `CreateDesignModel`（ObservableObject）里，两步共用：返回改内容再进来，样式还在。
///   第 2 步**不能**直接读第 1 步的 @State：navigationDestination 推出来的页面不会随之刷新，
///   11-27「切换样式预览不生效」就是这个原因。
/// - 没有「应用」按钮、没有二级面板：每个选项点下去预览立刻换（圆形揭开），不满意点右上角撤销。
/// - 选项缩略图用用户自己的内容在后台渲染，只重画变了的那几张。
/// - PRO 样式可以随便试，只在保存 / 分享时弹付费墙。

/// 两步共用的样式状态。
final class CreateDesignModel: ObservableObject {
    @Published var style: QRCodeStyle
    /// 用户自己导入的中心图标（方形照片，渲染时按圆角方块裁剪）。
    @Published var customLogo: UIImage?
    /// 换图时自增：`UIImage` 判等不可靠，靠这个计数器驱动重画。
    @Published var logoVersion = 0
    /// 本次表单已经写进历史的那条记录。再点分享 / 保存时更新它，而不是又插一条。
    var savedRecord: ScanRecord?

    init(style: QRCodeStyle) {
        self.style = style
    }
}

/// 推入第 2 步时带过去的内容（推入那一刻就定下来，第 2 步里不会变）。
struct CreateStudioInput: Hashable, Identifiable {
    let payload: String
    let kind: BarcodeKind
    let note: String

    var id: String { "\(kind.rawValue)|\(payload)" }
}

// MARK: - 第 1 步：填写内容

struct CreateFormView: View {

    let mode: CreateMode

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var design: CreateDesignModel

    @State private var draft = CreateDraft()
    @State private var kind: BarcodeKind
    @State private var message: String?
    /// 表单备注，保存到历史时一起落盘。
    @State private var note = ""
    @State private var didApplyDebug = false
    @State private var didDebugRoute = false
    @FocusState private var focusedField: String?
    @State private var studioInput: CreateStudioInput?
    /// 各区块的入场（只播一次）。
    @State private var appeared = false
    /// 内容不完整时点「生成」：按钮左右抖一下。
    @State private var shakeCount: CGFloat = 0
    /// 点过一次「生成」之后才实时显示校验错误：边打字边报「网址无效」很烦。
    @State private var hasAttempted = false

    init(mode: CreateMode) {
        self.mode = mode
        _kind = State(initialValue: mode.fixedKind ?? .qr)
        // 从首页品牌 / 类型入口进来：默认就带品牌图标——品牌色方块 + 白色图标。
        var initial = QRCodeStyle()
        if case .type(let type) = mode {
            initial.logoSource = .brand
            initial.logoTileHex = type.brandHex
        }
        _design = StateObject(wrappedValue: CreateDesignModel(style: initial))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                inputHeader
                    .modifier(Entrance(isVisible: appeared, order: 0, reduceMotion: reduceMotion))

                VStack(alignment: .leading, spacing: 18) {
                    fields
                    noteField
                }
                .modifier(Entrance(isVisible: appeared, order: 1, reduceMotion: reduceMotion))

                if let message {
                    errorBanner(message)
                        .transition(.lift)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
            .animation(Theme.Motion.smooth, value: message)
        }
        .background(CreateScreenBackground())
        // 键盘上方的「完成」：多行输入（文本、短信内容、备注）回车是换行，
        // 电话 / 数字键盘根本没有回车键——这两种情况都只能靠它一键收起。
        // 用 safeAreaInset 而不是 ToolbarItemGroup(placement: .keyboard)：后者在 iOS 26 上
        // 键盘没完全起来时会浮在屏幕底部。键盘弹出时底部安全区包含键盘，这条就正好贴在键盘上沿。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focusedField != nil {
                keyboardAccessory
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.resolve(Theme.Motion.snappy, reduceMotion: reduceMotion), value: focusedField != nil)
        // 导航栏不放「收起键盘」按钮（11-27：右上角只留「生成」）。收键盘：点空白处 / 下拉滚动 / 回车（回车直接生成）。
        .dismissKeyboardOnTap()
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { CreateStepIndicator(step: 1, isComplete: true) }
            ToolbarItem(placement: .topBarTrailing) { generateButton }
        }
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .onSubmit(goToStudio)
        .onChange(of: draftKey) { _, _ in
            if hasAttempted { _ = validate() }
        }
        .sensoryFeedback(.error, trigger: shakeCount)
        .navigationDestination(item: $studioInput) { input in
            CreateStudioView(mode: mode, input: input, design: design)
        }
        .onAppear {
            if !appeared { appeared = true }
            applyDebugPrefill()
            #if DEBUG
            if !didDebugRoute {
                didDebugRoute = true
                if DebugLaunchOptions.styleSheet || DebugLaunchOptions.autosaveHistory {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { goToStudio() }
                }
                if DebugLaunchOptions.autofocus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { focusedField = "primary" }
                }
            }
            #endif
        }
    }

    /// 导航栏右上角的「生成」。永远是实心可点的强调色（不变灰）：
    /// 内容不完整时点它 → 按钮左右抖一下 + 错误触感 + 页面里出提示，不进第二步。
    private var generateButton: some View {
        Button(action: goToStudio) {
            Text(L10n.Create.generate)
                .font(.body.weight(.semibold))
        }
        .modifier(NavProminentStyle())
        .modifier(ShakeEffect(animatableData: shakeCount))
        .accessibilityLabel(L10n.Create.generate)
    }

    /// 贴在键盘上沿右侧的玻璃胶囊「完成」。只在有输入框聚焦时出现。
    private var keyboardAccessory: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                focusedField = nil
            } label: {
                Label(L10n.Common.done, systemImage: "keyboard.chevron.compact.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .labelStyle(.titleAndIcon)
            }
            .modifier(SmallGlassCapsuleStyle())
            .accessibilityLabel(L10n.Common.done)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, 8)
    }

    private func goToStudio() {
        hasAttempted = true
        guard let payload = validate() else {
            withAnimation(.linear(duration: 0.42)) { shakeCount += 1 }
            return
        }
        focusedField = nil
        studioInput = CreateStudioInput(payload: payload, kind: kind, note: note)
    }

    /// 校验内容并返回要编码的字符串；不合格时把原因写进 `message`。
    /// 码制自身的规则（EAN 位数、校验位…）只有真画一次才知道，所以最后试渲染一张素码。
    private func validate() -> String? {
        do {
            guard let payload = try mode.payload(from: draft) else {
                message = L10n.Create.errorEmpty
                return nil
            }
            guard payload.utf8.count <= QRGeneratorService.maxByteCount else {
                message = L10n.Create.errorTooLong
                return nil
            }
            _ = try BarcodeImageGenerator.render(value: payload, kind: kind)
            message = nil
            return payload
        } catch let error as CreateBuildError {
            message = error.errorDescription
        } catch let error as BarcodeGenerationError {
            message = error.errorDescription
        } catch {
            message = L10n.Create.errorFailed
        }
        return nil
    }

    // MARK: - 头部 Hero 卡片

    /// 第一步头部：类型色块大图标 + 大标题 + 一句填写说明。
    private var inputHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(mode.tint)

                heroIcon
                    .foregroundStyle(.white)
                    .scaleEffect(1.25)
            }
            .frame(width: 64, height: 64)
            .shadow(color: mode.tint.opacity(0.28), radius: 14, y: 7)

            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text(modeSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroIcon: some View {
        switch mode {
        case .type(let type):
            BrandMark(type: type, size: 24)
        case .barcode(let kind):
            BarcodeMark(kind: kind, size: 24)
        case .custom:
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .bold))
        }
    }

    private var modeSubtitle: String {
        switch mode {
        case .type(let type):
            if type.isSocial {
                return L10n.Create.subtitleSocial
            } else if type == .wifi {
                return L10n.Create.subtitleWiFi
            } else if type == .contact {
                return L10n.Create.subtitleContact
            } else {
                return L10n.Create.subtitleGeneric
            }
        case .barcode:
            return L10n.Create.subtitleBarcode
        case .custom:
            return L10n.Create.subtitleCustom
        }
    }

    // MARK: - 字段区

    @ViewBuilder
    private var fields: some View {
        switch mode {
        case .type(let type):
            // 每个字段自己是一块输入框，不再外包一张大卡片。
            VStack(alignment: .leading, spacing: 18) {
                typeFields(type)
            }

        case .barcode, .custom:
            VStack(alignment: .leading, spacing: 18) {
                if mode.canChooseFormat {
                    formatPicker

                    // 只有"自选码制"才需要比一比各码制的字符集限制；
                    // 已经进了 EAN-13 页面还念叨"条码不接受链接"是废话。
                    if kind.isOneDimensional {
                        Text(L10n.Create.formatFooter)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                field(L10n.Create.textLabel, key: "primary") {
                    rawField
                }
            }
        }
    }

    /// 自由输入：一维码只给一行（条码没有换行概念），二维给多行。
    private var rawField: some View {
        TextField(
            rawPlaceholder,
            text: $draft.primary,
            axis: kind.isOneDimensional ? .horizontal : .vertical
        )
        .font(Theme.Typography.body)
        .foregroundStyle(Theme.Palette.textPrimary)
        .lineLimit(kind.isOneDimensional ? 1...1 : 4...8)
        // 多行框空着的时候只有一行高，给个下限，否则整卡片看起来像没填东西。
        .frame(minHeight: kind.isOneDimensional ? 22 : 92, alignment: .topLeading)
        .keyboardType(kind.acceptsDigitsOnly ? .numberPad : .default)
        .textInputAutocapitalization(kind.isOneDimensional ? .characters : .sentences)
        .autocorrectionDisabled(kind.isOneDimensional)
    }

    @ViewBuilder
    private func typeFields(_ type: CreateType) -> some View {
        switch type {
        // 社交平台：只要把主页上的那串名字填进来，别的一概不问。
        case .instagram, .tiktok, .youtube, .facebook, .whatsapp,
             .telegram, .linkedin, .x, .wechat, .xiaohongshu:
            inputWell("primary") {
                BrandMark(type: type, size: 22)
                    .foregroundStyle(type.tint)
            } content: {
                TextField(socialPlaceholder(type), text: $draft.primary)
                    .keyboardType(type == .whatsapp ? .phonePad : .default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }

        case .website:
            field(L10n.Create.websiteLabel) {
                TextField(L10n.Create.websitePlaceholder, text: $draft.primary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
            }

        case .text:
            field(L10n.Create.textLabel) {
                TextField(L10n.Create.textPlaceholder, text: $draft.primary, axis: .vertical)
                    .lineLimit(4...8)
            }
            characterCount

        case .email:
            field(L10n.Create.labelEmail) {
                TextField(L10n.Create.placeholderEmail, text: $draft.primary)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
            }

        case .sms:
            field(L10n.Create.labelPhone) {
                TextField(L10n.Create.placeholderPhone, text: $draft.primary)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            field(L10n.Create.labelMessage) {
                TextField(L10n.Create.placeholderMessage, text: $draft.secondary, axis: .vertical)
                    .lineLimit(3...5)
            }

        case .phone:
            field(L10n.Create.labelPhone) {
                TextField(L10n.Create.placeholderPhone, text: $draft.primary)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

        case .wifi:
            field(L10n.Create.labelSSID) {
                TextField(L10n.Create.placeholderSSID, text: $draft.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(L10n.Create.labelSecurity)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.leading, 4)

                Picker(L10n.Create.labelSecurity, selection: $draft.wifiSecurity) {
                    ForEach(WiFiSecurity.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            if draft.wifiSecurity != .none {
                field(L10n.Create.labelPassword) {
                    SecureField(L10n.Create.placeholderPassword, text: $draft.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Toggle(isOn: $draft.wifiHidden) {
                Text(L10n.Create.labelHiddenNetwork)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .tint(Theme.Palette.primaryFill)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )

        case .contact:
            field(L10n.Create.labelName) {
                TextField(L10n.Create.placeholderName, text: $draft.primary)
                    .textContentType(.name)
            }
            field(L10n.Create.labelPhone) {
                TextField(L10n.Create.placeholderPhone, text: $draft.secondary)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            field(L10n.Create.labelEmail) {
                TextField(L10n.Create.placeholderEmail, text: $draft.tertiary)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
            }
            field(L10n.Create.labelOrganisation) {
                TextField(L10n.Create.placeholderOrganisation, text: $draft.quaternary)
            }

        case .location:
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                field(L10n.Create.labelLatitude) {
                    TextField(L10n.Create.placeholderLatitude, text: $draft.primary)
                        .keyboardType(.numbersAndPunctuation)
                }
                field(L10n.Create.labelLongitude) {
                    TextField(L10n.Create.placeholderLongitude, text: $draft.secondary)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            Text(L10n.Create.locationHint)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func socialPlaceholder(_ type: CreateType) -> String {
        switch type {
        case .whatsapp: return L10n.Create.placeholderPhone
        case .wechat: return L10n.Create.placeholderWeChat
        default: return L10n.Create.placeholderHandle
        }
    }

    private var rawPlaceholder: String {
        switch kind {
        case .ean13: return "5901234123457"
        case .ean8: return "96385074"
        case .code128: return "ABC-123456"
        case .code39: return "ABC-123"
        case .qr, .aztec, .pdf417: return L10n.Create.textPlaceholder
        }
    }

    private var characterCount: some View {
        // QR 容量按 UTF-8 字节算：中文 / emoji 一个字符 3–4 字节。
        Text(verbatim: "\(draft.primary.utf8.count) / \(QRGeneratorService.maxByteCount)")
            .font(Theme.Typography.caption)
            .foregroundStyle(
                draft.primary.utf8.count > QRGeneratorService.maxByteCount
                    ? Theme.Palette.error
                    : Theme.Palette.textSecondary
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func field<Content: View>(
        _ label: String,
        key: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)

            inputWell(key ?? label, content: content)
        }
    }

    private func inputWell<Content: View>(
        _ key: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        inputWell(key, leading: { EmptyView() }, content: content)
    }

    /// 输入框：纯色底 + 细描边，聚焦时描边换成品牌蓝并浮起一点。没有渐变。
    private func inputWell<Leading: View, Content: View>(
        _ key: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isFocused = focusedField == key
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 12) {
            leading()
            content()
                .focused($focusedField, equals: key)
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Theme.Palette.surface, in: shape)
        .overlay(
            shape.strokeBorder(
                isFocused ? Theme.Palette.primary : Theme.Palette.border,
                lineWidth: isFocused ? 1.5 : 1
            )
        )
        .shadow(color: Theme.Palette.primary.opacity(isFocused ? 0.14 : 0), radius: 12, y: 5)
        .scaleEffect(isFocused && !reduceMotion ? 1.01 : 1)
        .animation(Theme.Motion.snappy, value: isFocused)
    }

    // MARK: - 码制（仅自定义）

    /// 七个码制自动换行。横向滚动必然把最后一个切成"EAN-1…"，用户看不出还有选项。
    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.Create.formatTitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            WrapLayout(spacing: Theme.Spacing.xs, lineSpacing: Theme.Spacing.xs) {
                ForEach(BarcodeKind.allCases) { option in
                    formatChip(option)
                }
            }
        }
    }

    private func formatChip(_ option: BarcodeKind) -> some View {
        let isSelected = kind == option
        return Button {
            guard kind != option else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            kind = option
        } label: {
            Text(option.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    Capsule().fill(isSelected ? Theme.Palette.primaryFill : Theme.Palette.background)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 备注 / 错误

    private var noteField: some View {
        field(L10n.Create.noteLabel) {
            TextField(L10n.Create.notePlaceholder, text: $note, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            WarningTriangleMark(size: 15)
                .foregroundStyle(Theme.Palette.error)
            Text(message)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.error)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Palette.error.opacity(0.10),
            in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
        )
    }

    // MARK: - 内容 key

    /// 所有字段拼成的一段 key，用来驱动实时重算（码制也算一位）。
    private var draftKey: String {
        [
            draft.primary,
            draft.secondary,
            draft.tertiary,
            draft.quaternary,
            draft.password,
            draft.wifiSecurity.rawValue,
            String(draft.wifiHidden),
            kind.rawValue
        ].joined(separator: "\u{1F}")
    }

    private func applyDebugPrefill() {
        #if DEBUG
        guard !didApplyDebug else { return }
        didApplyDebug = true
        if let value = DebugLaunchOptions.prefillGenerator {
            // 支持 "a|b" 一次填两个字段（定位、短信、联系人这类双输入表单截图要用）。
            let parts = value.components(separatedBy: "|")
            draft.primary = parts[0]
            if parts.count > 1 { draft.secondary = parts[1] }
            if parts.count > 2 { draft.tertiary = parts[2] }
        }
        if let raw = DebugLaunchOptions.barcodeKind, let preset = BarcodeKind(rawValue: raw) {
            kind = preset
        }
        if let raw = DebugLaunchOptions.stylePreset {
            // 形状|图标|前景|背景，只覆盖给出的部分。
            let parts = raw.components(separatedBy: "|")
            if parts.count > 0, let shape = DotShape(rawValue: parts[0]) { design.style.dotShape = shape }
            if parts.count > 1 {
                design.style.logoSource = parts[1] == "true" || parts[1] == "brand" ? .brand : .none
            }
            if parts.count > 2, let hex = UInt32(parts[2], radix: 16) { design.style.foregroundHex = hex }
            if parts.count > 3, let hex = UInt32(parts[3], radix: 16) { design.style.backgroundHex = hex }
        }
        if DebugLaunchOptions.customLogo {
            design.customLogo = DebugLogoImage.make()
            design.style.logoSource = .custom
            design.logoVersion += 1
        }
        if let raw = DebugLaunchOptions.templateID,
           let template = CodeTemplate.withID(raw) {
            // 放在最后：模板是一整套预设，会覆盖上面手动给的颜色/形状，
            // 但 logoSource（含刚塞进去的自定义图标）会保留。
            design.style = template.applying(to: design.style)
        }
        #endif
    }

}

// MARK: - 第 2 步：设计样式

private enum StudioTab: String, CaseIterable, Identifiable {
    case presets
    case dots
    case eyes
    case colors
    case logo
    case templates

    var id: String { rawValue }

    /// 选项多到收起高度放不下的分类：切过去时抽屉自动展开。
    /// 模板有分类条 + 13 张卡，收起时只露一行半；其他分类收起时都能完整看到。
    var prefersExpandedDrawer: Bool {
        self == .templates
    }

    var title: String {
        switch self {
        case .presets: return L10n.Create.tabPresets
        case .dots: return L10n.Create.tabDots
        case .eyes: return L10n.Create.tabEyes
        case .colors: return L10n.Create.tabColors
        case .logo: return L10n.Create.tabLogo
        case .templates: return L10n.Create.tabTemplates
        }
    }
}

/// 一张选项缩略图的渲染任务。`signature` = 样式 JSON + 图标版本，没变就不重画。
private struct ThumbJob {
    let key: String
    let style: QRCodeStyle
    /// 单位坐标的裁切区域（码点 / 码眼选项只看局部，放大了才看得出差别）。nil = 整张。
    let crop: CGRect?
    let signature: String

    init(key: String, style: QRCodeStyle, crop: CGRect? = nil, logoVersion: Int) {
        self.key = key
        self.style = style
        self.crop = crop
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = (try? encoder.encode(style)).map { String(decoding: $0, as: UTF8.self) } ?? key
        signature = "\(json)|\(logoVersion)"
    }
}

/// 按单位坐标裁一块（不受 MainActor 约束，后台任务里用）。
private func cropImage(_ image: UIImage, to unit: CGRect) -> UIImage {
    guard let cgImage = image.cgImage else { return image }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let rect = CGRect(
        x: unit.minX * width,
        y: unit.minY * height,
        width: unit.width * width,
        height: unit.height * height
    ).integral
    guard let cropped = cgImage.cropping(to: rect) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
}

/// 系统分享面板用 UIKit 直接 present，避免和全屏出示抢 presentation。
@MainActor
private func presentActivitySheet(_ image: UIImage) {
    let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
          let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
    var top = root
    while let presented = top.presentedViewController { top = presented }
    controller.popoverPresentationController?.sourceView = top.view
    controller.popoverPresentationController?.sourceRect = CGRect(
        x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1
    )
    top.present(controller, animated: true)
}

private struct CreateStudioView: View {

    let mode: CreateMode
    let input: CreateStudioInput
    @ObservedObject var design: CreateDesignModel

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var codeNamespace
    @Namespace private var tabNamespace
    @Namespace private var selectionNamespace

    @State private var image: UIImage?
    @State private var imageVersion = 0
    @State private var revealsNextImage = false
    /// 推入转场走完再把码放出来，圆形揭开才看得见。
    @State private var stageReady = false
    @State private var message: String?

    @State private var tab: StudioTab = .presets
    @State private var tabEdge: Edge = .trailing
    @State private var templateCategory: CodeTemplateCategory = .all

    @State private var thumbs: [String: UIImage] = [:]
    @State private var thumbSignatures: [String: String] = [:]
    @State private var thumbTask: Task<Void, Never>?

    /// 撤销栈（最多 30 步）。取色器拖动时连续的改动合并成一步。
    @State private var undoStack: [QRCodeStyle] = []
    @State private var coalesceKey: String?

    @State private var isShowcasing = false
    @State private var savedPulse = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var cachedBrandLogo: UIImage?

    // 抽屉：两档（收起 / 展开），可拖动、可轻点把手切换。
    @State private var drawerExpanded = false
    /// 拖动中的位移（向上为负）。松手后带弹簧回到最近的一档。
    @State private var drawerDrag: CGFloat = 0
    /// 这次拖动是否已认定为「竖向拖抽屉」（横向的是切分类 / 滚分类条）。
    @State private var drawerDragging = false
    /// 当前的展开是不是切分类时自动展开的。是 → 切回普通分类时自动收起；
    /// 用户自己拖过 / 点过把手 → 这个状态归用户，切分类不再自动收起。
    @State private var drawerAutoExpanded = false

    /// 抽屉头部（把手 + 分类条 + 间距）大约的高度，用来算展开时面板能有多高。
    private static let drawerHeaderAllowance: CGFloat = 86
    /// 展开时上面的码最少还留这么高（码会跟着缩小，但始终看得见）。
    private static let minStageHeight: CGFloat = 200

    private var kind: BarcodeKind { input.kind }
    private var style: QRCodeStyle { design.style }
    private var isPremium: Bool { subscriptions.isPremium }
    private var isLocked: Bool { !isPremium && style.usesPremiumFeatures }

    private var tabs: [StudioTab] {
        kind == .qr ? StudioTab.allCases : [.colors]
    }

    private var brandLogoAvailable: Bool {
        if case .type = mode { return true }
        return false
    }

    /// 收起时面板高度。一维码只有「条颜色 + 背景色」两行色板，留足不被裁。
    private var panelHeight: CGFloat { kind == .qr ? 236 : 172 }

    /// 换样式时的圆形揭开：比首次出场短一点，连续点几下也不拖沓。
    private var revealAnimation: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.45)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = drawerMetrics(in: proxy.size)
            let height = drawerHeight(metrics)
            let progress = drawerProgress(height, metrics)
            VStack(spacing: 0) {
                stage(progress: progress, metrics: metrics)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                controls(panelHeight: height, metrics: metrics)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(CreateScreenBackground())
        .overlay(alignment: .top) { toastOverlay }
        .navigationTitle(L10n.Create.stepDesign)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                CreateStepIndicator(step: 2, isComplete: stageReady)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !undoStack.isEmpty {
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(L10n.Create.undo)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $isShowcasing) { showcase }
        .photosPicker(isPresented: $showingPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            if let item { loadPicked(item) }
        }
        .onChange(of: design.style) { _, _ in
            render(animated: true)
            scheduleThumbnails()
        }
        .onChange(of: design.logoVersion) { _, _ in
            render(animated: true)
            scheduleThumbnails()
        }
        .onChange(of: tab) { _, _ in scheduleThumbnails() }
        .sensoryFeedback(.selection, trigger: design.style)
        .sensoryFeedback(.success, trigger: savedPulse) { _, new in new }
        .task {
            guard !stageReady else {
                scheduleThumbnails()
                return
            }
            render(animated: false)
            scheduleThumbnails()
            #if DEBUG
            if DebugLaunchOptions.autosaveHistory { saveToHistory() }
            #endif
            revealsNextImage = !reduceMotion
            withAnimation(reduceMotion ? Theme.Motion.fade : Theme.Motion.reveal.delay(0.3)) {
                stageReady = true
            }
        }
        .onDisappear {
            thumbTask?.cancel()
        }
    }

    // MARK: 舞台

    private func stage(progress: CGFloat, metrics: DrawerMetrics) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            Button {
                guard image != nil else { return }
                isShowcasing = true
            } label: {
                // 先用透明方块把位置占住，码出现时版面不跳。
                Color.clear
                    .aspectRatio(kind.isOneDimensional ? 2 : 1, contentMode: .fit)
                    .frame(maxWidth: kind.isOneDimensional ? .infinity : 280)
                    .overlay {
                        if let image, stageReady {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
                                .id(imageVersion)
                                .transition(revealsNextImage ? .qrReveal : .opacity)
                        }
                    }
                    .overlay {
                        if savedPulse {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Theme.Palette.success)
                                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .heroTransitionSource(id: "studio.code", in: codeNamespace)
            .padding(.horizontal, Theme.Spacing.pageMargin + 8)
            .accessibilityLabel(L10n.Create.present)

            stageCaption
                .frame(minHeight: 36)
                // 抽屉往上拉时这一行先淡出，把地方让给码。
                .opacity(Double(max(0, 1 - progress * 1.8)))

            Spacer(minLength: 8)
        }
        // 码以外的空白处：展开时轻点收起；上下拖也能带动抽屉。
        .contentShape(Rectangle())
        .onTapGesture {
            if drawerExpanded { setDrawer(expanded: false) }
        }
        .simultaneousGesture(drawerGesture(metrics))
        .animation(Theme.Motion.success, value: savedPulse)
        .animation(Theme.Motion.smooth, value: isLocked)
    }

    /// 码下面一行：出错 > PRO 提示（可点，去解锁）> 内容摘要。
    @ViewBuilder
    private var stageCaption: some View {
        if let message {
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.Palette.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        } else if isLocked {
            Button { _ = requiresUnlock() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(L10n.Create.proPreviewTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(verbatim: "·")
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(L10n.Create.proUnlock)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassSurface(.capsule, interactive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else {
            Text(verbatim: input.payload.replacingOccurrences(of: "\n", with: " "))
                .font(.footnote.monospaced())
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .transition(.opacity)
        }
    }

    // MARK: 控制区（底部抽屉）

    private func controls(panelHeight height: CGFloat, metrics: DrawerMetrics) -> some View {
        VStack(spacing: 14) {
            drawerHeader(metrics)

            ZStack(alignment: .top) {
                panel(for: tab)
                    .id(tab)
                    .transition(panelTransition)
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(height, 0), alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(swipe)

            // 保存 / 分享放在抽屉里（不再用浮在页面上的底栏）：
            // 底栏会盖住抽屉最下面一行（一维码的背景色板就被它挡住了）。
            actionBar
                .opacity(image == nil ? 0.4 : 1)
                .disabled(image == nil)
        }
        .padding(.bottom, 2)
        .background {
            // 抽屉底用页面灰（深色模式是深灰），白底的码 / 缩略图在上面才是一张张卡片，而不是白茫茫一片。
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Theme.Palette.background)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                        .strokeBorder(Theme.Palette.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 18, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: drawerExpanded)
    }

    /// 把手 + 分类条。整块都能上下拖；把手单独可点（展开 / 收起），也给 VoiceOver 用。
    private func drawerHeader(_ metrics: DrawerMetrics) -> some View {
        VStack(spacing: 10) {
            Button {
                setDrawer(expanded: !drawerExpanded)
            } label: {
                Capsule(style: .continuous)
                    .fill(Theme.Palette.textSecondary.opacity(drawerDragging ? 0.6 : 0.32))
                    .frame(width: drawerDragging ? 44 : 36, height: 5)
                    .frame(width: 96, height: 18)
                    .contentShape(Rectangle())
                    .animation(Theme.Motion.snappy, value: drawerDragging)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(drawerExpanded ? L10n.Create.drawerCollapse : L10n.Create.drawerExpand)

            if tabs.count > 1 {
                tabBar
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(drawerGesture(metrics))
    }

    // MARK: 抽屉拖动

    private struct DrawerMetrics {
        let collapsed: CGFloat
        let expanded: CGFloat
        var canExpand: Bool { expanded - collapsed > 40 }
    }

    private func drawerMetrics(in size: CGSize) -> DrawerMetrics {
        let collapsed = panelHeight
        let expanded = max(collapsed, size.height - Self.minStageHeight - Self.drawerHeaderAllowance)
        return DrawerMetrics(collapsed: collapsed, expanded: expanded)
    }

    /// 当前面板高度：停靠的那一档减去手指位移；超出两档时只跟手 25%（橡皮筋）。
    private func drawerHeight(_ metrics: DrawerMetrics) -> CGFloat {
        guard metrics.canExpand else { return metrics.collapsed }
        let base = drawerExpanded ? metrics.expanded : metrics.collapsed
        let raw = base - drawerDrag
        if raw > metrics.expanded {
            return metrics.expanded + (raw - metrics.expanded) * 0.25
        }
        if raw < metrics.collapsed {
            return max(metrics.collapsed - 48, metrics.collapsed - (metrics.collapsed - raw) * 0.25)
        }
        return raw
    }

    private func drawerProgress(_ height: CGFloat, _ metrics: DrawerMetrics) -> CGFloat {
        guard metrics.canExpand else { return 0 }
        return min(1, max(0, (height - metrics.collapsed) / (metrics.expanded - metrics.collapsed)))
    }

    /// 只认竖向拖动：一开始横向位移更大的手势留给分类条滚动 / 左右切分类。
    /// 松手时按「惯性落点」决定停在哪一档，轻轻一甩也能展开 / 收起。
    private func drawerGesture(_ metrics: DrawerMetrics) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard metrics.canExpand else { return }
                if !drawerDragging {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    drawerDragging = true
                }
                drawerDrag = value.translation.height
            }
            .onEnded { value in
                guard drawerDragging else { return }
                drawerDragging = false
                let base = drawerExpanded ? metrics.expanded : metrics.collapsed
                let projected = base - value.predictedEndTranslation.height
                setDrawer(expanded: projected > (metrics.collapsed + metrics.expanded) / 2)
            }
    }

    /// `byUser`：用户亲手拖 / 点的（默认）。自动展开传 false，以后切回普通分类时才会自动收起。
    private func setDrawer(expanded: Bool, byUser: Bool = true) {
        drawerAutoExpanded = !byUser && expanded
        let spring: Animation = reduceMotion
            ? Theme.Motion.fade
            : .spring(response: 0.42, dampingFraction: 0.86)
        withAnimation(spring) {
            drawerExpanded = expanded
            drawerDrag = 0
        }
    }

    /// 分类：纯文字，选中的那个底下滑过一块品牌蓝胶囊。
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs) { item in
                    tabButton(item)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
        .scrollClipDisabled()
    }

    private func tabButton(_ item: StudioTab) -> some View {
        let isSelected = item == tab
        return Button { select(item) } label: {
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.Palette.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.Palette.primaryFill)
                            .matchedGeometryEffect(id: "studio.tab", in: tabNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var panelTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let opposite: Edge = tabEdge == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: tabEdge).combined(with: .opacity),
            removal: .move(edge: opposite).combined(with: .opacity)
        )
    }

    /// 在选项区左右滑动切换分类。
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.6,
                      let index = tabs.firstIndex(of: tab) else { return }
                let next = dx < 0 ? index + 1 : index - 1
                guard tabs.indices.contains(next) else { return }
                select(tabs[next])
            }
    }

    private func select(_ next: StudioTab) {
        guard next != tab else { return }
        let from = tabs.firstIndex(of: tab) ?? 0
        let to = tabs.firstIndex(of: next) ?? 0
        tabEdge = to > from ? .trailing : .leading
        withAnimation(Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)) {
            tab = next
        }
        // 分类切换和抽屉高度一起动：面板滑进来的同时抽屉升起 / 落下。
        if next.prefersExpandedDrawer, !drawerExpanded {
            setDrawer(expanded: true, byUser: false)
        } else if !next.prefersExpandedDrawer, drawerExpanded, drawerAutoExpanded {
            setDrawer(expanded: false, byUser: false)
        }
    }

    @ViewBuilder
    private func panel(for tab: StudioTab) -> some View {
        switch tab {
        case .presets: scrollable { presetsPanel }
        case .dots: scrollable { dotsPanel }
        case .eyes: scrollable { eyesPanel }
        case .colors: colorsPanel
        case .logo: scrollable { logoPanel }
        case .templates: templatesPanel
        }
    }

    /// 面板内容超出当前高度时可以竖向滚；放得下就不弹（抽屉收起 / 展开两种高度都适用）。
    private func scrollable<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .padding(.bottom, 10)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func columns(_ count: Int, spacing: CGFloat = 12) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    // MARK: 面板：精选

    private var presetsPanel: some View {
        let selected = QRStylePreset.all.first { $0.matches(style) }
        return LazyVGrid(columns: columns(4), spacing: 12) {
            ForEach(QRStylePreset.all) { preset in
                optionTile(
                    key: "preset.\(preset.id)",
                    title: preset.name,
                    backdrop: Color(hex: preset.backgroundHex),
                    isSelected: selected?.id == preset.id,
                    isLocked: preset.isPremium && !isPremium,
                    ringID: "ring.presets"
                ) {
                    mutate { $0 = preset.applying(to: $0) }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, 4)
    }

    // MARK: 面板：码点

    private var dotsPanel: some View {
        LazyVGrid(columns: columns(4), spacing: 12) {
            ForEach(DotShape.allCases) { shape in
                optionTile(
                    key: "dot.\(shape.rawValue)",
                    title: shape.title,
                    backdrop: Color(hex: style.backgroundHex),
                    isSelected: style.dotShape == shape,
                    isLocked: shape.isPremium && !isPremium,
                    zoomed: true,
                    ringID: "ring.dots"
                ) {
                    mutate { $0.dotShape = shape }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, 4)
    }

    // MARK: 面板：码眼（外框 + 内块分开选）

    private var eyesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyeRow(title: L10n.Create.eyeFrame, isBall: false)
            eyeRow(title: L10n.Create.eyeBall, isBall: true)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, 2)
    }

    private func eyeRow(title: String, isBall: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle(title)
            LazyVGrid(columns: columns(5, spacing: 10), spacing: 10) {
                ForEach(EyeShape.allCases) { eye in
                    optionTile(
                        key: "\(isBall ? "ball" : "eye").\(eye.rawValue)",
                        title: eye.title,
                        backdrop: Color(hex: style.backgroundHex),
                        isSelected: (isBall ? style.resolvedEyeBallShape : style.resolvedEyeShape) == eye,
                        isLocked: eye.isPremium && !isPremium,
                        zoomed: true,
                        compact: true,
                        ringID: isBall ? "ring.ball" : "ring.eye"
                    ) {
                        mutate {
                            if isBall {
                                $0.eyeBallShape = eye
                            } else {
                                $0.eyeShape = eye
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: 面板：颜色

    private static let eyeAccents: [UInt32] = [
        0x2449E6, 0x0A72B8, 0x1C7A4B, 0xC8441F, 0xA3214A, 0x5B3FE0, 0xE1306C
    ]

    private var colorsPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                colorRow(
                    title: kind == .qr ? L10n.Create.styleForeground : L10n.Create.styleBars,
                    swatches: QRCodeStyle.foregroundSwatches,
                    selected: style.foregroundHex,
                    custom: Binding(
                        get: { Color(hex: design.style.foregroundHex) },
                        set: { color in mutate(coalescing: "fg") { setForeground(Self.hex(of: color), on: &$0) } }
                    )
                ) { hex in
                    mutate { setForeground(hex, on: &$0) }
                }

                if kind == .qr {
                    eyeColorRow
                }

                colorRow(
                    title: L10n.Create.styleBackground,
                    swatches: QRCodeStyle.backgroundSwatches,
                    selected: style.backgroundHex,
                    custom: Binding(
                        get: { Color(hex: design.style.backgroundHex) },
                        set: { color in mutate(coalescing: "bg") { $0.backgroundHex = Self.hex(of: color) } }
                    )
                ) { hex in
                    mutate { $0.backgroundHex = hex }
                }

                if style.isLowContrast {
                    HStack(spacing: 6) {
                        WarningTriangleMark(size: 14)
                        Text(L10n.Create.styleLowContrast)
                            .font(Theme.Typography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.Palette.warning)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, 4)
            .animation(Theme.Motion.smooth, value: style.isLowContrast)
        }
    }

    private func colorRow(
        title: String,
        swatches: [UInt32],
        selected: UInt32,
        custom: Binding<Color>,
        onPick: @escaping (UInt32) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(swatches, id: \.self) { hex in
                        swatch(hex: hex, isSelected: selected == hex) { onPick(hex) }
                    }
                    // 系统取色器：色板之外的任意颜色。
                    ColorPicker("", selection: custom, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 38, height: 38)
                }
                .padding(.vertical, 3)
            }
            .scrollClipDisabled()
        }
    }

    /// 码眼颜色：「同码点」或一个强调色（外框用强调色，内块保持码点色 = 双色眼）。
    private var eyeColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle(L10n.Create.colorEyes)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let matches = style.eyeHex == nil
                    Button {
                        mutate {
                            $0.eyeHex = nil
                            $0.eyeBallHex = nil
                        }
                    } label: {
                        Text(L10n.Create.colorMatch)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(matches ? Theme.Palette.primary : Theme.Palette.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(matches ? Theme.Palette.primary : Theme.Palette.border, lineWidth: matches ? 2 : 1)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.92))

                    ForEach(Self.eyeAccents, id: \.self) { hex in
                        swatch(hex: hex, isSelected: style.eyeHex == hex) {
                            mutate {
                                $0.eyeHex = hex
                                $0.eyeBallHex = $0.foregroundHex
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollClipDisabled()
        }
    }

    private func swatch(hex: UInt32, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !isSelected else { return }
            action()
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
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

    /// 换码点颜色时，原来跟着码点色的定位角也跟着换；单独设了强调色的不动。
    private func setForeground(_ hex: UInt32, on style: inout QRCodeStyle) {
        let old = style.foregroundHex
        style.foregroundHex = hex
        if style.eyeHex == old { style.eyeHex = nil }
        if style.eyeBallHex == old { style.eyeBallHex = style.eyeHex == nil ? nil : hex }
    }

    private static func hex(of color: Color) -> UInt32 {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        _ = UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> UInt32 {
            UInt32(max(0, min(255, (value * 255).rounded())))
        }
        return channel(red) << 16 | channel(green) << 8 | channel(blue)
    }

    // MARK: 面板：中心图标

    private var logoPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                logoOption(.none)
                if brandLogoAvailable {
                    logoOption(.brand)
                }
                logoOption(.custom)
                Spacer(minLength: 0)
            }

            if style.logoSource == .custom, design.customLogo != nil {
                HStack(spacing: 18) {
                    Button(L10n.Create.logoReplace) { showingPicker = true }
                        .foregroundStyle(Theme.Palette.primary)
                    Button(L10n.Create.logoRemove, action: removeCustomLogo)
                        .foregroundStyle(Theme.Palette.error)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Text(L10n.Create.styleLogoHint)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, 4)
        .animation(Theme.Motion.smooth, value: style.logoSource)
    }

    private func logoOption(_ option: LogoSource) -> some View {
        let isSelected = style.logoSource == option
        return Button { pickLogo(option) } label: {
            VStack(spacing: 6) {
                logoArtwork(option)
                    .frame(width: 76, height: 76)
                    .background(Theme.Palette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.Palette.border, lineWidth: 1)
                    )
                    .overlay { selectionRing(isSelected, cornerRadius: 19, id: "ring.logo") }

                caption(option.title, isLocked: option == .custom && !isPremium, isSelected: isSelected)
            }
            .frame(width: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func logoArtwork(_ option: LogoSource) -> some View {
        switch option {
        case .none:
            Image(systemName: "slash.circle")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
        case .brand:
            if case .type(let type) = mode {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: style.logoTileHex ?? style.resolvedEyeHex))
                    .frame(width: 44, height: 44)
                    .overlay {
                        BrandMark(type: type, size: 22)
                            .foregroundStyle(.white)
                    }
            }
        case .custom:
            if let logo = design.customLogo {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                PhotoBadgePlusMark(size: 26)
                    .foregroundStyle(Theme.Palette.primary)
            }
        }
    }

    private func pickLogo(_ option: LogoSource) {
        if option == .custom, design.customLogo == nil {
            showingPicker = true
            return
        }
        mutate { $0.logoSource = option }
    }

    private func loadPicked(_ item: PhotosPickerItem) {
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                pickerItem = nil
                guard let data, let picked = UIImage(data: data) else {
                    message = L10n.Create.errorFailed
                    return
                }
                design.customLogo = picked.scaledDown(to: 512)
                design.logoVersion += 1
                mutate { $0.logoSource = .custom }
            }
        }
    }

    private func removeCustomLogo() {
        design.customLogo = nil
        design.logoVersion += 1
        mutate { $0.logoSource = brandLogoAvailable ? .brand : .none }
    }

    // MARK: 面板：模板

    private var templatesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CodeTemplateCategory.allCases) { item in
                        categoryChip(item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns(4), spacing: 12) {
                    if templateCategory == .all {
                        optionTile(
                            key: "tpl.none",
                            title: L10n.Templates.none,
                            backdrop: Color(hex: style.backgroundHex),
                            isSelected: style.templateID == nil,
                            isLocked: false,
                            ringID: "ring.tpl"
                        ) {
                            mutate { $0.templateID = nil }
                        }
                    }
                    ForEach(CodeTemplate.inCategory(templateCategory)) { template in
                        optionTile(
                            key: "tpl.\(template.id)",
                            title: template.name,
                            backdrop: template.canvasColor,
                            isSelected: style.templateID == template.id,
                            isLocked: template.isPremium && !isPremium,
                            ringID: "ring.tpl"
                        ) {
                            mutate { $0 = template.applying(to: $0) }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.vertical, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private func categoryChip(_ item: CodeTemplateCategory) -> some View {
        let isSelected = templateCategory == item
        return Button {
            withAnimation(Theme.Motion.resolve(Theme.Motion.snappy, reduceMotion: reduceMotion)) {
                templateCategory = item
            }
        } label: {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isSelected ? Theme.Palette.primary : Theme.Palette.border, lineWidth: isSelected ? 1.5 : 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
    }

    // MARK: 选项格子

    /// 一个选项：实时缩略图 + 名字。选中环在同一组格子之间滑动。
    private func optionTile(
        key: String,
        title: String,
        backdrop: Color,
        isSelected: Bool,
        isLocked: Bool,
        zoomed: Bool = false,
        compact: Bool = false,
        ringID: String,
        action: @escaping () -> Void
    ) -> some View {
        let radius: CGFloat = compact ? 12 : 14
        return Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(backdrop)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let thumb = thumbs[key] {
                            Image(uiImage: thumb)
                                .resizable()
                                .interpolation(.medium)
                                .scaledToFit()
                                .padding(zoomed ? 0 : 5)
                                .transition(.opacity)
                        } else {
                            // 还没画好：小菊花，不留一个空白框。
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.Palette.textSecondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.Palette.border, lineWidth: 1)
                    )
                    .overlay { selectionRing(isSelected, cornerRadius: radius + 3.5, id: ringID) }

                caption(title, isLocked: isLocked, isSelected: isSelected, compact: compact)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectionRing(_ isSelected: Bool, cornerRadius: CGFloat, id: String) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.Palette.primary, lineWidth: 2.5)
                .padding(-3.5)
                .matchedGeometryEffect(id: id, in: selectionNamespace)
        }
    }

    private func caption(_ title: String, isLocked: Bool, isSelected: Bool, compact: Bool = false) -> some View {
        HStack(spacing: 3) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: compact ? 8 : 9, weight: .bold))
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: compact ? 11 : 12, weight: isSelected ? .semibold : .medium))
        .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary)
    }

    private func panelTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
    }

    // MARK: 改样式 / 撤销

    /// 所有样式改动都走这里：记一步撤销，再带动画写回共享模型（选中环跟着滑）。
    private func mutate(coalescing key: String? = nil, _ change: (inout QRCodeStyle) -> Void) {
        var next = design.style
        change(&next)
        guard next != design.style else { return }
        if key == nil || key != coalesceKey {
            undoStack.append(design.style)
            if undoStack.count > 30 { undoStack.removeFirst() }
        }
        coalesceKey = key
        withAnimation(Theme.Motion.resolve(Theme.Motion.snappy, reduceMotion: reduceMotion)) {
            design.style = next
        }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        coalesceKey = nil
        withAnimation(Theme.Motion.resolve(Theme.Motion.snappy, reduceMotion: reduceMotion)) {
            design.style = previous
        }
    }

    // MARK: 渲染

    private func render(animated: Bool) {
        do {
            let rendered = try BarcodeImageGenerator.render(
                value: input.payload,
                kind: kind,
                style: style,
                logo: resolveLogo(for: style)
            )
            revealsNextImage = animated && !reduceMotion
            if animated {
                withAnimation(revealsNextImage ? revealAnimation : Theme.Motion.fade) {
                    image = rendered
                    imageVersion += 1
                }
            } else {
                image = rendered
                imageVersion += 1
            }
            message = nil
        } catch let error as BarcodeGenerationError {
            message = error.errorDescription
        } catch {
            message = L10n.Create.errorFailed
        }
    }

    private func resolveLogo(for style: QRCodeStyle) -> UIImage? {
        switch style.logoSource {
        case .none:
            return nil
        case .custom:
            return design.customLogo
        case .brand:
            guard case .type(let type) = mode else { return nil }
            if let cachedBrandLogo { return cachedBrandLogo }
            // 渲染器会把品牌图标染成白色放在品牌色方块上，这里的颜色无所谓。
            let rendered = BrandMarkRenderer.logo(for: type, side: 84, color: .black)
            cachedBrandLogo = rendered
            return rendered
        }
    }

    private func thumbnailJobs(for tab: StudioTab) -> [ThumbJob] {
        let base = style
        let version = design.logoVersion
        // 码点看右下角一块、码眼看左上角一块（放大后才看得出差别）；不带模板外框。
        let dotCrop = CGRect(x: 0.6, y: 0.6, width: 0.36, height: 0.36)
        let eyeCrop = CGRect(x: 0.04, y: 0.04, width: 0.36, height: 0.36)
        switch tab {
        case .presets:
            return QRStylePreset.all.map {
                ThumbJob(key: "preset.\($0.id)", style: $0.applying(to: base), logoVersion: version)
            }
        case .dots:
            return DotShape.allCases.map { shape in
                var next = base
                next.templateID = nil
                next.dotShape = shape
                return ThumbJob(key: "dot.\(shape.rawValue)", style: next, crop: dotCrop, logoVersion: version)
            }
        case .eyes:
            let frames = EyeShape.allCases.map { eye -> ThumbJob in
                var next = base
                next.templateID = nil
                next.eyeShape = eye
                return ThumbJob(key: "eye.\(eye.rawValue)", style: next, crop: eyeCrop, logoVersion: version)
            }
            let balls = EyeShape.allCases.map { eye -> ThumbJob in
                var next = base
                next.templateID = nil
                next.eyeBallShape = eye
                return ThumbJob(key: "ball.\(eye.rawValue)", style: next, crop: eyeCrop, logoVersion: version)
            }
            return frames + balls
        case .templates:
            var plain = base
            plain.templateID = nil
            return [ThumbJob(key: "tpl.none", style: plain, logoVersion: version)]
                + CodeTemplate.all.map {
                    ThumbJob(key: "tpl.\($0.id)", style: $0.applying(to: base), logoVersion: version)
                }
        case .colors, .logo:
            return []
        }
    }

    /// 后台只重画样式真的变了的那几张；旧图留着直到新图出来，不闪。
    private func scheduleThumbnails() {
        guard kind == .qr else { return }
        let jobs = thumbnailJobs(for: tab).filter { thumbSignatures[$0.key] != $0.signature }
        guard !jobs.isEmpty else { return }
        thumbTask?.cancel()
        let logo = resolveLogo(for: style)
        let value = input.payload
        // 11-27：缩略图全是空白框——后台线程里画图（UIGraphicsImageRenderer 默认格式 / 模板合成都会
        // 碰 UIScreen、UITraitCollection）不可靠。改成主线程一张一张画，每张之间让出一次主线程，
        // 用明确的小倍数出图：整张 0.75x（约 370px），局部放大 1.4x（裁完约 250px），单张几毫秒。
        thumbTask = Task { @MainActor in
            for job in jobs {
                await Task.yield()
                guard !Task.isCancelled else { return }
                guard let full = try? BarcodeImageGenerator.render(
                    value: value,
                    kind: .qr,
                    style: job.style,
                    logo: logo,
                    scale: job.crop == nil ? 0.75 : 1.4
                ) else { continue }
                let piece = job.crop.map { cropImage(full, to: $0) } ?? full
                withAnimation(Theme.Motion.fade) {
                    thumbs[job.key] = piece
                }
                thumbSignatures[job.key] = job.signature
            }
        }
    }

    // MARK: PRO

    /// 用了 PRO 样式且没买断：弹付费墙并返回 true（调用方就此停下）。
    private func requiresUnlock() -> Bool {
        guard isLocked else { return false }
        PaywallTriggerManager.shared.triggerFeatureGate(style.templateID ?? "create.style")
        return true
    }

    // MARK: 底部操作

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: saveToPhotos) {
                Label(L10n.Result.save, systemImage: isLocked ? "lock.fill" : "square.and.arrow.down")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .contentTransition(.symbolEffect(.replace))
            }
            .modifier(GlassCapsuleStyle())

            Button(action: share) {
                Label(L10n.Result.share, systemImage: isLocked ? "lock.fill" : "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .contentTransition(.symbolEffect(.replace))
            }
            .modifier(ProminentCapsuleStyle(large: true))
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, 2)
        .padding(.bottom, Theme.Spacing.xs)
        .animation(Theme.Motion.snappy, value: isLocked)
    }

    private func share() {
        guard !requiresUnlock(), let image else { return }
        saveToHistory()
        presentActivitySheet(image)
    }

    private func saveToPhotos() {
        guard !requiresUnlock(), let image else { return }
        // 与历史详情共用 PhotoLibrary.save（只申请 addOnly）。只有真的存进相册才落历史。
        PhotoLibrary.save(image) { success in
            if success {
                saveToHistory()
                celebrateSave(L10n.Create.saved)
            } else {
                message = L10n.Create.saveFailed
            }
        }
    }

    /// 把当前这张码写进历史（同一次表单只写一条；再保存只更新样式和备注）。
    private func saveToHistory() {
        if requiresUnlock() { return }
        let payload = input.payload
        if let record = design.savedRecord, record.rawValue == payload,
           record.barcodeFormat == kind.barcodeFormat {
            HistoryStore.updateNote(input.note, on: record, in: modelContext)
            HistoryStore.updateStyle(style, logo: resolveLogo(for: style), on: record, in: modelContext)
            return
        }
        guard let record = HistoryStore.saveGenerated(
            value: payload,
            kind: kind,
            note: input.note,
            style: style,
            logo: resolveLogo(for: style),
            in: modelContext,
            isPremium: isPremium
        ) else {
            message = L10n.Create.saveFailed
            return
        }
        design.savedRecord = record
        PaywallTriggerManager.shared.recordGenerateSuccess(isPremium: isPremium)
    }

    // MARK: 全屏出示 / 提示

    @ViewBuilder
    private var showcase: some View {
        if let image {
            let background = style.template?.canvasColor ?? style.background
            if #available(iOS 18.0, *) {
                QRShowcaseView(image: image, background: background)
                    .navigationTransition(.zoom(sourceID: "studio.code", in: codeNamespace))
            } else {
                QRShowcaseView(image: image, background: background)
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMessage {
            FeedbackToast(systemImage: "checkmark.circle.fill", message: toastMessage)
                .padding(.top, Theme.Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func celebrateSave(_ text: String) {
        toastTask?.cancel()
        withAnimation(Theme.Motion.success) {
            savedPulse = true
            toastMessage = text
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Theme.Motion.fade) {
                savedPulse = false
                toastMessage = nil
            }
        }
    }
}

// MARK: - 步骤指示

/// 导航栏中间：当前步骤名 + 两段进度条。第二段在第 2 步出现时从左往右「画」满。
private struct CreateStepIndicator: View {
    let step: Int
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(step == 1 ? L10n.Create.stepFill : L10n.Create.stepDesign)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)

            HStack(spacing: 4) {
                ForEach(1...2, id: \.self) { index in
                    let filled = index < step || (index == step && isComplete)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.border)
                        Capsule()
                            .fill(Theme.Palette.primary)
                            .scaleEffect(x: filled ? 1 : 0.001, anchor: .leading)
                    }
                    .frame(width: 22, height: 3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step == 1 ? L10n.Create.stepFill : L10n.Create.stepDesign)
    }
}

// MARK: - 入场 / 抖动 / zoom 推入

/// 第一步各区块依次上浮淡入，只在第一次出现时播。
private struct Entrance: ViewModifier {
    let isVisible: Bool
    let order: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .animation(Theme.Motion.smooth.delay(Double(order) * 0.07), value: isVisible)
    }
}

/// 左右抖三下后回到原位（animatableData 每 +1 抖一轮）。
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 7 * sin(animatableData * .pi * 6), y: 0)
        )
    }
}

/// iOS 18+：第二步从「生成」按钮 zoom 展开；低版本走普通推入。
private struct ZoomDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

// MARK: - 圆形揭开

/// 遮罩圆从中心长到覆盖整张图：换样式时新码像被「显影」出来。不用渐变，纯几何遮罩。
private struct CircularRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { proxy in
                    let diameter = hypot(proxy.size.width, proxy.size.height) * progress
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .scaleEffect(0.94 + 0.06 * progress)
    }
}

private extension AnyTransition {
    static var qrReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CircularRevealModifier(progress: 0.001),
                identity: CircularRevealModifier(progress: 1)
            ),
            // 旧图稍晚淡出：新图揭开的过程里底下还看得到旧图，衔接不断。
            removal: .opacity.animation(.easeOut(duration: 0.3).delay(0.25))
        )
    }
}

// MARK: - 全屏出示

/// 全屏出示：码的底色铺满屏幕、码放到最大、亮度拉满，方便别人扫码；轻点任意处关闭，关闭后恢复亮度。
private struct QRShowcaseView: View {
    let image: UIImage
    let background: Color

    @Environment(\.dismiss) private var dismiss
    @State private var originalBrightness: CGFloat?

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer(minLength: 0)
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 380)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer(minLength: 0)
                Text(L10n.Create.showcaseHint)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassSurface(.capsule)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .light), trigger: originalBrightness != nil)
        .onAppear(perform: boostBrightness)
        .onDisappear(perform: restoreBrightness)
    }

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }

    private func boostBrightness() {
        guard let screen, originalBrightness == nil else { return }
        originalBrightness = screen.brightness
        screen.brightness = 1
    }

    private func restoreBrightness() {
        guard let screen, let originalBrightness else { return }
        screen.brightness = originalBrightness
        self.originalBrightness = nil
    }
}

// MARK: - 按钮与操作栏样式（iOS 26 原生 Liquid Glass，低版本退回实心 / 描边）

private struct FormActionBar<Bar: View>: ViewModifier {
    let isVisible: Bool
    @ViewBuilder var bar: () -> Bar

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) {
                if isVisible {
                    bar().transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                if isVisible {
                    bar()
                        .background(.bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

private struct GlassCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        } else {
            content.buttonStyle(SecondaryButtonStyle())
        }
    }
}

private struct SmallGlassCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            content
                .padding(.horizontal, Theme.Spacing.s)
                .frame(height: 34)
                .glassSurface(.capsule, interactive: true)
                .buttonStyle(PressableButtonStyle())
        }
    }
}

/// 导航栏里的强调按钮：iOS 26 用系统液态玻璃强调样式（品牌蓝），低版本用品牌蓝粗体文字。
private struct NavProminentStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(Theme.Palette.primaryFill)
        } else {
            content
                .foregroundStyle(Theme.Palette.primary)
        }
    }
}

private struct ProminentCapsuleStyle: ViewModifier {
    let large: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(large ? .large : .regular)
                .tint(Theme.Palette.primaryFill)
                .foregroundStyle(.white)
        } else if large {
            content.buttonStyle(PrimaryButtonStyle())
        } else {
            content
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Theme.Palette.primaryFill, in: Capsule(style: .continuous))
                .buttonStyle(PressableButtonStyle())
        }
    }
}

#Preview("Tipo") {
    NavigationStack {
        CreateFormView(mode: .type(.instagram))
    }
    .environmentObject(SubscriptionManager())
    .modelContainer(for: ScanRecord.self, inMemory: true)
}

#Preview("Barras") {
    NavigationStack {
        CreateFormView(mode: .barcode(.ean13))
    }
    .environmentObject(SubscriptionManager())
    .modelContainer(for: ScanRecord.self, inMemory: true)
}
