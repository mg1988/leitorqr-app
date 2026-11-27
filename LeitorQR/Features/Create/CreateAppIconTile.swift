import SwiftUI

/// 符合 Apple HIG 设计规范的高级图标磁贴：
/// - 52×52 连续曲率圆角矩形（Squircle），与 iOS 系统图标比例严密契合
/// - 品牌色纯色底托（不用渐变）
/// - 同色系柔和投影（Ambient Colored Shadow）
/// - 纯白居中高清矢量图形（26×26），视觉中心稳定
struct CreateAppIconTile<Mark: View>: View {

    let title: String
    let tint: Color
    let action: () -> Void
    @ViewBuilder let mark: () -> Mark

    var body: some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // 品牌色纯色 Squircle 底座
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint)

                    // 纯白高反差矢量图形
                    mark()
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                }
                .frame(width: 52, height: 52)
                .shadow(color: tint.opacity(0.26), radius: 6, y: 3)

                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .accessibilityLabel(title)
    }
}

/// 内容类型 / 条形码用的软磁贴：15% 类型色浅底 + 类型色图标。
///
/// 和品牌磁贴同尺寸（52pt squircle + 11.5pt 标题），网格里对得齐；
/// 但不用渐变和彩色投影——这些类型没有品牌色要还原，颜色只承担「分类」这一个信息。
struct CreateSoftTile<Mark: View>: View {

    let title: String
    let tint: Color
    let action: () -> Void
    @ViewBuilder let mark: () -> Mark

    var body: some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.14))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 0.8)

                    mark()
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                }
                .frame(width: 52, height: 52)

                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .accessibilityLabel(title)
    }
}
