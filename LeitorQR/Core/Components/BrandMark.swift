import SwiftUI

/// 平台图标。
///
/// 全部用 SwiftUI 形状自绘，不引第三方资源：
/// - 只用**单色**绘制，颜色由外层 `foregroundStyle` 给（未选中＝品牌色，选中＝白），
///   这样同一个图标在两种状态下都不用准备两套。
/// - 实心图形里的镂空（YouTube 的三角、Facebook 的 f、WhatsApp 的话筒）走
///   `.blendMode(.destinationOut)` + `.compositingGroup()`，镂空处透出卡片底色，
///   不写死白色——否则深色模式下会出现白块。
/// - 设计基准是 24×24，外层按 `size` 整体缩放，各图标视觉重量因此保持一致。
struct BrandMark: View {
    let type: CreateType
    var size: CGFloat = 24

    var body: some View {
        content
            .frame(width: 24, height: 24)
            .scaleEffect(size / 24)
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        switch type {
        case .instagram: InstagramMark()
        case .tiktok: TikTokMark()
        case .youtube: YouTubeMark()
        case .facebook: FacebookMark()
        case .whatsapp: WhatsAppMark()
        case .telegram: TelegramMark()
        case .linkedin: LinkedInMark()
        case .x: XMark()
        case .wechat: WeChatMark()
        case .xiaohongshu: XiaohongshuMark()
        case .website: WebsiteMark()
        case .text: TextMark()
        case .wifi: WiFiMark()
        case .contact: ContactMark()
        case .email: EmailMark()
        case .sms: SMSMark()
        case .phone: PhoneMark()
        case .location: LocationMark()
        }
    }
}

// MARK: - 社交平台

/// 圆角方框 + 镜头圆 + 右上闪光点。
private struct InstagramMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.6, style: .continuous)
                .strokeBorder(lineWidth: 2)
                .frame(width: 21, height: 21)

            Circle()
                .strokeBorder(lineWidth: 2)
                .frame(width: 8.8, height: 8.8)

            Circle()
                .frame(width: 2.4, height: 2.4)
                .offset(x: 5.4, y: -5.4)
        }
    }
}

/// 音符：符头在左下、竖杆向上、顶端向右卷出一段符尾。
/// 坐标直接写在 24×24 画布里，比"形状 + offset"堆叠更好对齐。
private struct TikTokMark: View {
    var body: some View {
        ZStack {
            // 符尾
            Path { path in
                path.move(to: CGPoint(x: 12.9, y: 4.6))
                path.addQuadCurve(
                    to: CGPoint(x: 19.4, y: 11.0),
                    control: CGPoint(x: 20.6, y: 4.8)
                )
            }
            .stroke(style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

            // 竖杆
            Capsule()
                .frame(width: 3.2, height: 15)
                .offset(x: 0.9, y: -0.6)

            // 符头
            Circle()
                .frame(width: 7.6, height: 7.6)
                .offset(x: -2.9, y: 6.9)
        }
        .frame(width: 24, height: 24)
    }
}

/// 圆角矩形 + 镂空的播放三角。
private struct YouTubeMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5.6, style: .continuous)
                .frame(width: 24, height: 17)

            PlayTriangle()
                .frame(width: 6.6, height: 7.8)
                .offset(x: 0.8)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 圆底 + 镂空的 f，和 WhatsApp / Telegram 保持同一种"实心圆里挖图形"的语言。
private struct FacebookMark: View {
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 22.5, height: 22.5)

            Text(verbatim: "f")
                .font(.system(size: 16.5, weight: .black, design: .serif))
                .offset(x: 0.8, y: 0.6)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// 气泡里的听筒。用纯手绘听筒矢量形状镂空。
private struct WhatsAppMark: View {
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 23, height: 23)

            Path { path in
                path.move(to: CGPoint(x: 3.5, y: 2.2))
                path.addLine(to: CGPoint(x: 5.6, y: 2.0))
                path.addLine(to: CGPoint(x: 6.5, y: 4.4))
                path.addLine(to: CGPoint(x: 5.2, y: 5.5))
                path.addQuadCurve(to: CGPoint(x: 8.5, y: 8.8), control: CGPoint(x: 6.5, y: 7.6))
                path.addLine(to: CGPoint(x: 9.6, y: 7.5))
                path.addLine(to: CGPoint(x: 12.0, y: 8.4))
                path.addLine(to: CGPoint(x: 11.8, y: 10.5))
                path.addQuadCurve(to: CGPoint(x: 9.0, y: 12.0), control: CGPoint(x: 10.8, y: 12.0))
                path.addQuadCurve(to: CGPoint(x: 2.0, y: 5.0), control: CGPoint(x: 2.0, y: 9.5))
                path.addQuadCurve(to: CGPoint(x: 3.5, y: 2.2), control: CGPoint(x: 2.0, y: 3.2))
                path.closeSubpath()
            }
            .fill()
            .frame(width: 14, height: 14)
            .offset(x: -0.2, y: 0.2)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// 圆 + 纸飞机纯矢量。
private struct TelegramMark: View {
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 23, height: 23)

            Path { path in
                path.move(to: CGPoint(x: 12.0, y: 2.0))
                path.addLine(to: CGPoint(x: 2.0, y: 6.8))
                path.addLine(to: CGPoint(x: 6.2, y: 8.4))
                path.addLine(to: CGPoint(x: 6.8, y: 12.0))
                path.addLine(to: CGPoint(x: 8.4, y: 9.2))
                path.addLine(to: CGPoint(x: 11.2, y: 11.0))
                path.closeSubpath()
            }
            .fill()
            .frame(width: 14, height: 14)
            .offset(x: -0.5, y: 0.3)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// 圆角方块 + 镂空的 in。
private struct LinkedInMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .frame(width: 22, height: 22)

            Text(verbatim: "in")
                .font(.system(size: 11.5, weight: .heavy))
                .offset(y: -0.8)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// 两根交叉的斜杆。
private struct XMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 3.0, height: 22)
                .rotationEffect(.degrees(36))

            Capsule()
                .frame(width: 3.0, height: 22)
                .rotationEffect(.degrees(-36))
        }
    }
}

/// 两个叠在一起的气泡：后面那个降透明度压出层次，前面的挖两个点当眼睛。
/// 官方 logo 是绿色双气泡，单色下只要轮廓能认出是"聊天气泡对"就够了。
private struct WeChatMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 12.5, height: 10)
                .offset(x: -3.6, y: -4.0)
                .opacity(0.5)

            Capsule()
                .frame(width: 15.5, height: 12)
                .offset(x: 2.8, y: 3.4)

            HStack(spacing: 3.2) {
                Circle().frame(width: 1.9, height: 1.9)
                Circle().frame(width: 1.9, height: 1.9)
            }
            .offset(x: 2.8, y: 3.4)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// "小红书"直译就是一本小书：圆角书壳 + 镂空书脊 + 两行字。
/// 比硬塞中文字或复制官方红底更耐看，也和其他单色图标同一种语言。
private struct XiaohongshuMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .frame(width: 20, height: 17)

            // 书脊：靠左的一条竖缝
            Rectangle()
                .frame(width: 2.2, height: 17)
                .offset(x: -6.0)
                .blendMode(.destinationOut)

            // 正文两行
            VStack(spacing: 2.8) {
                Capsule().frame(width: 7.6, height: 1.7)
                Capsule().frame(width: 5.6, height: 1.7)
            }
            .offset(x: 2.4)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach([CreateType.social, CreateType.others], id: \.self) { group in
            HStack(spacing: 18) {
                ForEach(group) { type in
                    BrandMark(type: type, size: 28)
                        .foregroundStyle(type.tint)
                }
            }
        }
    }
    .padding()
}

// MARK: - 渲染成位图

/// 把品牌图标画成 `UIImage`，供二维码中心图标使用。
///
/// 走 `ImageRenderer` 而不是另画一套 Core Graphics 路径：
/// 图标里的镂空是靠 `.blendMode(.destinationOut)` 做的，
/// 只有让 SwiftUI 自己渲染才能得到正确的透明区域。
@MainActor
enum BrandMarkRenderer {

    static func logo(for type: CreateType, side: CGFloat, color: Color) -> UIImage? {
        let content = BrandMark(type: type, size: side)
            .foregroundStyle(color)
            .frame(width: side, height: side)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
