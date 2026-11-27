import SwiftUI

/// 液态玻璃（Liquid Glass）兼容层。
///
/// 设计原则（对齐 Apple HIG · Liquid Glass）：
/// 1. 玻璃只用在**功能层**——悬浮在内容之上的导航、控件、操作按钮；
///    内容本身（卡片列表、表单）仍用不透明 `surface`，不做玻璃套玻璃。
/// 2. 同一区域的多个玻璃控件放进 `GlassEffectContainer`（见 `GlassGroup`），
///    让系统统一计算折射与融合。
/// 3. 文字永远压在玻璃上；摄像头这类高动态画面下改用 `.dark` 色调，
///    否则玻璃会采样到亮背景而变浅，白字直接糊掉。
/// 4. 强调操作使用系统 `.glassProminent`，不自己拼「半透明色块 + 白字」。
///
/// iOS 26 以下（本项目最低 iOS 17）退回 `.ultraThinMaterial` + 细高光描边，
/// 保持同一套调用点与视觉层级，避免两套 UI 分叉。
extension View {

    /// 给视图套一层带有菲涅尔反射与内倒角光晕的增强型液态玻璃表面。
    /// - Parameters:
    ///   - shape: 玻璃形状（capsule / circle / roundedRectangle）。
    ///   - tone: 明暗倾向。压在摄像头、深色照片等高亮画面上时用 `.dark`。
    ///   - tint: 强调色染色（如手电筒点亮）。
    ///   - interactive: 是否启用系统交互反馈（按下时玻璃形变与高光）。
    @ViewBuilder
    func glassSurface<S: InsettableShape>(
        _ shape: S,
        tone: GlassTone = .auto,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26：只用系统液态玻璃。系统自带折射、高光和按压形变，
            // 再叠手绘高光边会让它看起来像一块塑料（2026-11-27 实测反馈）。
            self
                .glassEffect(
                    makeGlass(tone: tone, tint: tint, interactive: interactive),
                    in: shape
                )
        } else {
            self
                .background(tone.fallbackWash, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    GlassSpecularBevel(shape: shape, tone: tone)
                }
        }
    }

    /// 玻璃卡片（内容自带内边距）。
    @ViewBuilder
    func glassCard(
        cornerRadius: CGFloat = Theme.Radius.card,
        tone: GlassTone = .auto,
        tint: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .padding(Theme.Spacing.m)
                .glassEffect(
                    makeGlass(tone: tone, tint: tint, interactive: false),
                    in: shape
                )
        } else {
            self
                .padding(Theme.Spacing.m)
                .background(tone.fallbackWash, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    GlassSpecularBevel(shape: shape, tone: tone)
                }
        }
    }
}

/// iOS 17–25 退路的玻璃描边：一圈纯色细线（不用渐变）。iOS 26 由系统 glassEffect 自带高光，不叠这层。
struct GlassSpecularBevel<S: InsettableShape>: View {
    let shape: S
    var tone: GlassTone = .auto

    var body: some View {
        shape
            .strokeBorder(Color.white.opacity(tone == .dark ? 0.22 : 0.4), lineWidth: 0.8)
            .allowsHitTesting(false)
    }
}

/// 玻璃的明暗倾向。
enum GlassTone {
    /// 跟随系统材质，用于常规页面背景之上。
    case auto
    /// 加深，用于摄像头、深色照片、高亮画面上承载白字。
    case dark

    /// iOS 26 的染色值。注意：`Glass.tint` 是**着色**，给黑色才会把玻璃压深；
    /// 试过用 `.background(black)` 叠洗色层，会被玻璃材质覆盖掉，无效。
    var tintColor: Color? {
        switch self {
        case .auto: return nil
        // 只压一点点：0.5 会把玻璃压成不透明的黑塑料，完全看不出是玻璃。
        // 白字的可读性主要靠调用方把相机页固定成深色外观。
        case .dark: return Color.black.opacity(0.14)
        }
    }

    /// iOS 17–25 的退路：material 之上压一层半透明黑，保证白字可读。
    var fallbackWash: Color {
        switch self {
        case .auto: return .clear
        case .dark: return Color.black.opacity(0.45)
        }
    }
}

@available(iOS 26.0, *)
private func makeGlass(tone: GlassTone, tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    // 两个染色只取一个：`tint` 会覆盖前一次，强调色（手电点亮）优先。
    if let tint {
        glass = glass.tint(tint)
    } else if let toneTint = tone.tintColor {
        glass = glass.tint(toneTint)
    }
    if interactive {
        glass = glass.interactive()
    }
    return glass
}

// MARK: - 玻璃按钮

/// 玻璃圆形图标按钮（扫描页手电筒等纯图标控件）。
///
/// 图标固定白色；开启时散发液态温暖光晕。
struct GlassCircleButton: View {
    let systemImage: String
    /// 开启态的轻微染色。注意只能给很低透明度：`Glass.tint` 是着色，
    /// 给 0.5 以上会把整个圆钮变成实心色块，比旁边控件显眼一大截。
    var tint: Color?
    var size: CGFloat = 40
    var accessibilityLabel: String
    /// 开启态的无障碍值，仅在手电筒这类可切换控件上提供。
    var isOn: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isOn == true ? Theme.Palette.torch : .white)
                    .frame(width: size, height: size)
                    .contentShape(Circle())

                // 开启态只用一圈细边提示，不再叠 blur 光晕——之前那层
                // `Circle().fill(...).blur(radius:8)` 让按钮视觉直径大了近一圈。
                if isOn == true {
                    Circle()
                        .strokeBorder(Theme.Palette.torch.opacity(0.55), lineWidth: 1.2)
                        .frame(width: size - 3, height: size - 3)
                }
            }
        }
        .buttonStyle(.plain)
        .glassSurface(.circle, tone: .dark, tint: tint, interactive: true)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isOn == true ? [.isSelected] : [])
    }
}

/// 强调型玻璃主按钮（本页唯一的主动作，如「Importar das Fotografias」）。
///
/// iOS 26 起直接用系统 `.glassProminent`：系统会按背景自动决定前景色与
/// 染色浓度，比手拼「半透明主色 + 白字」在明亮镜头画面里更稳。
struct GlassPrimaryButton: View {
    let title: String
    let systemImage: String
    var height: CGFloat = 52
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Palette.primaryFill)
        } else {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Theme.Palette.primaryFill, in: Capsule(style: .continuous))
        }
    }

    private var label: some View {
        Label(title, systemImage: systemImage)
            .font(Theme.Typography.button)
            // 显式白色：`.glassProminent` 在深色模式下会把前景压成次级灰，
            // 压在深蓝填充上就糊了。
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Capsule())
    }
}

// MARK: - 玻璃控件容器

/// 把同一视觉区域内的玻璃控件聚合到 `GlassEffectContainer`。
///
/// iOS 26 以下直接透传（`ultraThinMaterial` 之间不需要融合计算）。
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = Theme.Spacing.s
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}
