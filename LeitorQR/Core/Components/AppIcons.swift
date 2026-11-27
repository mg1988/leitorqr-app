import SwiftUI

/// 纯手绘矢量图标库（AppIcons）。
///
/// 遵循统一的几何规范：
/// - 基准画布统一为 24×24 或 18×18。
/// - 线宽统一为 1.6~2.0pt，线帽与拐角均为圆润收口（Round Cap & Join）。
/// - 纯单色矢量呈现，自动继承外层 `foregroundStyle`。
/// - 杜绝任何系统 SF Symbols，确保跨平台风格纯粹且高度定制化。
enum AppIcons {
    // 命名空间封装
}

// MARK: - 基础内容类型图标（24×24）

/// 网址 / 浏览器：立体经纬度地球网格
struct WebsiteMark: View {
    var body: some View {
        ZStack {
            // 外圈圆
            Circle()
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 20, height: 20)

            // 赤道横线
            Path { path in
                path.move(to: CGPoint(x: 2, y: 12))
                path.addLine(to: CGPoint(x: 22, y: 12))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            // 本初子午线椭圆
            Ellipse()
                .strokeBorder(lineWidth: 1.6)
                .frame(width: 10, height: 20)

            // 竖直经线
            Path { path in
                path.move(to: CGPoint(x: 12, y: 2))
                path.addLine(to: CGPoint(x: 12, y: 22))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}

/// 纯文本：折角文档 + 排版横线
struct TextMark: View {
    var body: some View {
        ZStack {
            // 文档外轮廓（带右上折角）
            Path { path in
                path.move(to: CGPoint(x: 5, y: 3))
                path.addLine(to: CGPoint(x: 14, y: 3))
                path.addLine(to: CGPoint(x: 19, y: 8))
                path.addLine(to: CGPoint(x: 19, y: 21))
                path.addLine(to: CGPoint(x: 5, y: 21))
                path.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // 右上折角三角折线
            Path { path in
                path.move(to: CGPoint(x: 14, y: 3))
                path.addLine(to: CGPoint(x: 14, y: 8))
                path.addLine(to: CGPoint(x: 19, y: 8))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            // 文档内容三道横线
            VStack(alignment: .leading, spacing: 2.8) {
                Capsule().frame(width: 9, height: 1.6)
                Capsule().frame(width: 9, height: 1.6)
                Capsule().frame(width: 6, height: 1.6)
            }
            .offset(x: -0.5, y: 2)
        }
        .frame(width: 24, height: 24)
    }
}

/// Wi-Fi：基座圆点 + 3 级同心扩散圆弧
struct WiFiMark: View {
    var body: some View {
        ZStack {
            // 底座圆点
            Circle()
                .frame(width: 3.2, height: 3.2)
                .offset(y: 7.5)

            // 第一级弧
            ArcShape(startAngle: -135, endAngle: -45, radius: 6.2)
                .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                .offset(y: 7.5)

            // 第二级弧
            ArcShape(startAngle: -135, endAngle: -45, radius: 10.8)
                .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                .offset(y: 7.5)

            // 第三级弧
            ArcShape(startAngle: -135, endAngle: -45, radius: 15.4)
                .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                .offset(y: 7.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 联系人 / 名片：头部圆点 + 流畅肩部弧线
struct ContactMark: View {
    var body: some View {
        ZStack {
            // 外圈细圆角边框
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 21, height: 21)

            // 头部圆
            Circle()
                .frame(width: 6.4, height: 6.4)
                .offset(y: -2.8)

            // 肩部弧线
            Path { path in
                path.addArc(
                    center: CGPoint(x: 12, y: 18),
                    radius: 5.6,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}

/// 邮件：圆角信封 + 居中 V 形折盖
struct EmailMark: View {
    var body: some View {
        ZStack {
            // 信封外轮廓
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 21, height: 16)

            // 信封折盖 V 线
            Path { path in
                path.move(to: CGPoint(x: 2.5, y: 5.5))
                path.addLine(to: CGPoint(x: 12, y: 12.5))
                path.addLine(to: CGPoint(x: 21.5, y: 5.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
    }
}

/// 短信 / 消息：对话气泡 + 气泡尾巴 + 三点
struct SMSMark: View {
    var body: some View {
        ZStack {
            // 对话气泡本体
            Path { path in
                path.move(to: CGPoint(x: 6, y: 4))
                path.addLine(to: CGPoint(x: 18, y: 4))
                path.addQuadCurve(to: CGPoint(x: 21, y: 7), control: CGPoint(x: 21, y: 4))
                path.addLine(to: CGPoint(x: 21, y: 15))
                path.addQuadCurve(to: CGPoint(x: 18, y: 18), control: CGPoint(x: 21, y: 18))
                path.addLine(to: CGPoint(x: 9, y: 18))
                path.addLine(to: CGPoint(x: 4, y: 21.5))
                path.addLine(to: CGPoint(x: 4.8, y: 17.5))
                path.addQuadCurve(to: CGPoint(x: 3, y: 15), control: CGPoint(x: 3, y: 17))
                path.addLine(to: CGPoint(x: 3, y: 7))
                path.addQuadCurve(to: CGPoint(x: 6, y: 4), control: CGPoint(x: 3, y: 4))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // 气泡内三点
            HStack(spacing: 2.2) {
                Circle().frame(width: 2.2, height: 2.2)
                Circle().frame(width: 2.2, height: 2.2)
                Circle().frame(width: 2.2, height: 2.2)
            }
            .offset(y: -1.2)
        }
        .frame(width: 24, height: 24)
    }
}

/// 电话：斜向斜切话筒手柄
struct PhoneMark: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 6.2, y: 4.5))
            path.addLine(to: CGPoint(x: 9.8, y: 4.2))
            path.addLine(to: CGPoint(x: 11.2, y: 7.8))
            path.addLine(to: CGPoint(x: 9.2, y: 9.5))
            path.addQuadCurve(to: CGPoint(x: 14.5, y: 14.8), control: CGPoint(x: 11.2, y: 13.0))
            path.addLine(to: CGPoint(x: 16.2, y: 12.8))
            path.addLine(to: CGPoint(x: 19.8, y: 14.2))
            path.addLine(to: CGPoint(x: 19.5, y: 17.8))
            path.addQuadCurve(to: CGPoint(x: 15.0, y: 20.0), control: CGPoint(x: 18.0, y: 20.0))
            path.addQuadCurve(to: CGPoint(x: 4.0, y: 9.0), control: CGPoint(x: 4.0, y: 16.0))
            path.addQuadCurve(to: CGPoint(x: 6.2, y: 4.5), control: CGPoint(x: 4.0, y: 6.0))
            path.closeSubpath()
        }
        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// 地理位置：水滴形图钉 + 居中圆孔
struct LocationMark: View {
    var body: some View {
        ZStack {
            // 水滴形轮廓
            Path { path in
                path.move(to: CGPoint(x: 12, y: 21.5))
                path.addCurve(
                    to: CGPoint(x: 4.5, y: 9.5),
                    control1: CGPoint(x: 9.5, y: 17.5),
                    control2: CGPoint(x: 4.5, y: 13.5)
                )
                path.addArc(
                    center: CGPoint(x: 12, y: 9.5),
                    radius: 7.5,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addCurve(
                    to: CGPoint(x: 12, y: 21.5),
                    control1: CGPoint(x: 19.5, y: 13.5),
                    control2: CGPoint(x: 14.5, y: 17.5)
                )
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // 图钉中心孔
            Circle()
                .frame(width: 4.8, height: 4.8)
                .offset(y: -2.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 日历事件：圆角台历 + 顶部挂环 + 日期格
struct EventMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 19, height: 17)
                .offset(y: 2)

            // 顶部横隔线
            Path { path in
                path.move(to: CGPoint(x: 2.5, y: 8))
                path.addLine(to: CGPoint(x: 21.5, y: 8))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // 两个挂环
            Path { path in
                path.move(to: CGPoint(x: 8, y: 2))
                path.addLine(to: CGPoint(x: 8, y: 5))
                path.move(to: CGPoint(x: 16, y: 2))
                path.addLine(to: CGPoint(x: 16, y: 5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // 日期格
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .frame(width: 4.6, height: 4.6)
                .offset(x: -3.6, y: 5.6)
        }
        .frame(width: 24, height: 24)
    }
}

/// 银行转账：银行卡 + 磁条。
///
/// 卡片图标在 14pt 的标签里只有 8pt 高，任何「芯片 + 卡号 + 磁条」的细节都会糊成一团，
/// 所以只留卡框和一条磁条——这两笔就足够读成「卡」。
struct PaymentMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 21, height: 14.5)

            // 磁条：压在卡框上沿下方，两端留出圆角的内缩。
            Path { path in
                path.move(to: CGPoint(x: 1.5, y: 8.4))
                path.addLine(to: CGPoint(x: 22.5, y: 8.4))
            }
            .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .butt))
        }
        .frame(width: 24, height: 24)
    }
}

/// 加密支付：硬币外圈 + 币种符号（B）。
///
/// 真实的 ₿ 还带两道竖枝，缩到 14pt 后只会变成两个小黑点，
/// 所以去掉竖枝，只留中间那个 B。
struct CryptoMark: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: 1.8)
                .frame(width: 20, height: 20)

            Path { path in
                path.move(to: CGPoint(x: 9.9, y: 7.3))
                path.addLine(to: CGPoint(x: 9.9, y: 16.7))

                path.move(to: CGPoint(x: 9.9, y: 7.7))
                path.addQuadCurve(to: CGPoint(x: 9.9, y: 11.9), control: CGPoint(x: 15.1, y: 9.8))
                path.addQuadCurve(to: CGPoint(x: 9.9, y: 16.3), control: CGPoint(x: 15.4, y: 14.1))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
    }
}

/// 扫描结果与历史记录的统一内容类型矢量图标
struct ContentTypeMark: View {
    let type: ScanContentType
    var size: CGFloat = 20

    var body: some View {
        Group {
            switch type {
            case .url: WebsiteMark().frame(width: size, height: size)
            case .text: TextMark().frame(width: size, height: size)
            case .wifi: WiFiMark().frame(width: size, height: size)
            case .email: EmailMark().frame(width: size, height: size)
            case .phone: PhoneMark().frame(width: size, height: size)
            case .sms: SMSMark().frame(width: size, height: size)
            case .contact: ContactMark().frame(width: size, height: size)
            case .location: LocationMark().frame(width: size, height: size)
            case .event: EventMark().frame(width: size, height: size)
            case .payment: PaymentMark().frame(width: size, height: size)
            case .crypto: CryptoMark().frame(width: size, height: size)
            case .barcode: BarcodeMark(kind: .code128, size: size)
            }
        }
    }
}

// MARK: - TabBar 导航图标（18×18 基准）

/// Tab 1: 扫描（取景框 + 中心扫描点阵）
struct TabScanMark: View {
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            // 四个角点
            Path { path in
                // 左上
                path.move(to: CGPoint(x: 1, y: 6))
                path.addLine(to: CGPoint(x: 1, y: 2.5))
                path.addQuadCurve(to: CGPoint(x: 2.5, y: 1), control: CGPoint(x: 1, y: 1))
                path.addLine(to: CGPoint(x: 6, y: 1))

                // 右上
                path.move(to: CGPoint(x: 12, y: 1))
                path.addLine(to: CGPoint(x: 15.5, y: 1))
                path.addQuadCurve(to: CGPoint(x: 17, y: 2.5), control: CGPoint(x: 17, y: 1))
                path.addLine(to: CGPoint(x: 17, y: 6))

                // 右下
                path.move(to: CGPoint(x: 17, y: 12))
                path.addLine(to: CGPoint(x: 17, y: 15.5))
                path.addQuadCurve(to: CGPoint(x: 15.5, y: 17), control: CGPoint(x: 17, y: 17))
                path.addLine(to: CGPoint(x: 12, y: 17))

                // 左下
                path.move(to: CGPoint(x: 6, y: 17))
                path.addLine(to: CGPoint(x: 2.5, y: 17))
                path.addQuadCurve(to: CGPoint(x: 1, y: 15.5), control: CGPoint(x: 1, y: 17))
                path.addLine(to: CGPoint(x: 1, y: 12))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round))

            // 中心瞄准扫描线或微矩阵
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .frame(width: 7.5, height: 7.5)
            } else {
                Circle()
                    .frame(width: 3.2, height: 3.2)
            }
        }
        .frame(width: 18, height: 18)
    }
}

/// Tab 2: 创建（QR 矩阵码块）
struct TabCreateMark: View {
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            // 左上定位方块
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: 6.8, height: 6.8)
                .offset(x: -4.5, y: -4.5)

            // 右上定位方块
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: 6.8, height: 6.8)
                .offset(x: 4.5, y: -4.5)

            // 左下定位方块
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: 6.8, height: 6.8)
                .offset(x: -4.5, y: 4.5)

            // 右下动态创建点或小十字
            if isSelected {
                Circle()
                    .frame(width: 4.5, height: 4.5)
                    .offset(x: 4.5, y: 4.5)
            } else {
                Rectangle()
                    .frame(width: 3.8, height: 3.8)
                    .offset(x: 4.5, y: 4.5)
            }
        }
        .frame(width: 18, height: 18)
    }
}

/// Tab 3: 历史（逆时针时钟回溯箭头）
struct TabHistoryMark: View {
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            // 逆时针圆弧（未闭合，留出左上箭头缺口）
            Path { path in
                path.addArc(
                    center: CGPoint(x: 9, y: 9),
                    radius: 7.2,
                    startAngle: .degrees(-65),
                    endAngle: .degrees(190),
                    clockwise: false
                )
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // 左上回转箭头尖
            Path { path in
                path.move(to: CGPoint(x: 1.0, y: 6.5))
                path.addLine(to: CGPoint(x: 2.2, y: 11.0))
                path.addLine(to: CGPoint(x: 6.5, y: 10.0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

            // 表针（时针分针）
            Path { path in
                path.move(to: CGPoint(x: 9, y: 5.2))
                path.addLine(to: CGPoint(x: 9, y: 9))
                path.addLine(to: CGPoint(x: 12.2, y: 9))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 18, height: 18)
    }
}

/// Tab 4: 设置（现代精密齿轮）
struct TabSettingsMark: View {
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            // 齿轮外圈凸起（6 齿）
            ForEach(0..<6) { i in
                Capsule()
                    .frame(width: 3.4, height: 17.5)
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // 齿轮主体圆盘
            Circle()
                .frame(width: 12.5, height: 12.5)

            // 中心镂空孔
            Circle()
                .frame(width: 5.2, height: 5.2)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: 18, height: 18)
    }
}

// MARK: - 通用辅助矢量图标

/// 优雅加号
struct PlusMark: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Capsule().frame(width: 2.5, height: size * 0.75)
            Capsule().frame(width: size * 0.75, height: 2.5)
        }
        .frame(width: size, height: size)
    }
}

/// 优雅对勾
struct CheckmarkMark: View {
    var size: CGFloat = 16

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.20, y: size * 0.52))
            path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.78))
            path.addLine(to: CGPoint(x: size * 0.82, y: size * 0.24))
        }
        .stroke(style: StrokeStyle(lineWidth: max(1.8, size * 0.12), lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// 优雅折叠箭头（朝下）
struct ChevronDownMark: View {
    var size: CGFloat = 14

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.20, y: size * 0.35))
            path.addLine(to: CGPoint(x: size * 0.50, y: size * 0.65))
            path.addLine(to: CGPoint(x: size * 0.80, y: size * 0.35))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// 优雅折叠箭头（朝右）
struct ChevronRightMark: View {
    var size: CGFloat = 14

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.35, y: size * 0.20))
            path.addLine(to: CGPoint(x: size * 0.65, y: size * 0.50))
            path.addLine(to: CGPoint(x: size * 0.35, y: size * 0.80))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// 警告三角形
struct WarningTriangleMark: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.15))
                path.addLine(to: CGPoint(x: size * 0.88, y: size * 0.85))
                path.addLine(to: CGPoint(x: size * 0.12, y: size * 0.85))
                path.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            VStack(spacing: 1.8) {
                Capsule().frame(width: 1.6, height: size * 0.28)
                Circle().frame(width: 1.6, height: 1.6)
            }
            .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

/// QR 占位简笔矢量
struct QRCodePlaceholderMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            // 三个角的定位框
            VStack(spacing: size * 0.22) {
                HStack(spacing: size * 0.22) {
                    finderCell(size: size * 0.36)
                    finderCell(size: size * 0.36)
                }
                HStack(spacing: size * 0.22) {
                    finderCell(size: size * 0.36)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .frame(width: size * 0.36, height: size * 0.36)
                        .opacity(0.4)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func finderCell(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(lineWidth: 2)
            Rectangle()
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
    }
}

/// 优雅关闭叉号
struct CloseMark: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.22, y: size * 0.22))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.78))
                path.move(to: CGPoint(x: size * 0.78, y: size * 0.22))
                path.addLine(to: CGPoint(x: size * 0.22, y: size * 0.78))
            }
            .stroke(style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// 照片矢量图标
struct PhotoMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: size, height: size * 0.82)

            Circle()
                .frame(width: size * 0.20, height: size * 0.20)
                .offset(x: -size * 0.22, y: -size * 0.16)

            Path { path in
                path.move(to: CGPoint(x: size * 0.15, y: size * 0.65))
                path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.36))
                path.addLine(to: CGPoint(x: size * 0.64, y: size * 0.56))
                path.addLine(to: CGPoint(x: size * 0.85, y: size * 0.38))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// 叠放照片库图标
struct PhotoOnRectangleMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            // 底层倾斜相框
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(lineWidth: 1.4)
                .frame(width: size * 0.86, height: size * 0.72)
                .rotationEffect(.degrees(-8))
                .offset(x: -size * 0.08, y: -size * 0.08)

            // 顶层平放相框
            PhotoMark(size: size * 0.88)
                .offset(x: size * 0.06, y: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

/// 照片添加图标
struct PhotoBadgePlusMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            PhotoMark(size: size * 0.85)
                .offset(x: -size * 0.08, y: size * 0.08)

            PlusMark(size: size * 0.52)
                .offset(x: size * 0.32, y: -size * 0.28)
        }
        .frame(width: size, height: size)
    }
}

/// 禁用斜线圆圈（None）
struct SlashCircleMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: 1.6)
                .frame(width: size * 0.9, height: size * 0.9)

            Path { path in
                path.move(to: CGPoint(x: size * 0.26, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.74, y: size * 0.74))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// 品牌徽章图标
struct BadgeAppMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: size * 0.88, height: size * 0.88)

            Circle()
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: size * 0.28, y: -size * 0.28)
        }
        .frame(width: size, height: size)
    }
}

/// 闪烁星芒（VIP / Pro / 样式）
struct SparklesMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            sparkleShape(width: size * 0.7, height: size * 0.7)
                .offset(x: -size * 0.12, y: size * 0.12)

            sparkleShape(width: size * 0.42, height: size * 0.42)
                .offset(x: size * 0.28, y: -size * 0.28)
        }
        .frame(width: size, height: size)
    }

    private func sparkleShape(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            let midX = width / 2
            let midY = height / 2
            path.move(to: CGPoint(x: midX, y: 0))
            path.addQuadCurve(to: CGPoint(x: width, y: midY), control: CGPoint(x: midX, y: midY))
            path.addQuadCurve(to: CGPoint(x: midX, y: height), control: CGPoint(x: midX, y: midY))
            path.addQuadCurve(to: CGPoint(x: 0, y: midY), control: CGPoint(x: midX, y: midY))
            path.addQuadCurve(to: CGPoint(x: midX, y: 0), control: CGPoint(x: midX, y: midY))
            path.closeSubpath()
        }
        .fill()
        .frame(width: width, height: height)
    }
}

/// 垃圾桶 / 删除
struct TrashMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            // 桶身
            Path { path in
                path.move(to: CGPoint(x: size * 0.22, y: size * 0.32))
                path.addLine(to: CGPoint(x: size * 0.30, y: size * 0.86))
                path.addQuadCurve(to: CGPoint(x: size * 0.40, y: size * 0.94), control: CGPoint(x: size * 0.31, y: size * 0.94))
                path.addLine(to: CGPoint(x: size * 0.60, y: size * 0.94))
                path.addQuadCurve(to: CGPoint(x: size * 0.70, y: size * 0.86), control: CGPoint(x: size * 0.69, y: size * 0.94))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.32))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            // 桶盖
            Path { path in
                path.move(to: CGPoint(x: size * 0.15, y: size * 0.32))
                path.addLine(to: CGPoint(x: size * 0.85, y: size * 0.32))
                path.move(to: CGPoint(x: size * 0.38, y: size * 0.32))
                path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.16))
                path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.16))
                path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.32))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            // 竖筋
            Path { path in
                path.move(to: CGPoint(x: size * 0.42, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.80))
                path.move(to: CGPoint(x: size * 0.58, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.56, y: size * 0.80))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// 闪电 / 闪光灯
struct BoltMark: View {
    var size: CGFloat = 18

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.55, y: size * 0.10))
            path.addLine(to: CGPoint(x: size * 0.20, y: size * 0.54))
            path.addLine(to: CGPoint(x: size * 0.48, y: size * 0.54))
            path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.92))
            path.addLine(to: CGPoint(x: size * 0.80, y: size * 0.46))
            path.addLine(to: CGPoint(x: size * 0.52, y: size * 0.46))
            path.closeSubpath()
        }
        .fill()
        .frame(width: size, height: size)
    }
}

/// 闪光灯关闭
struct BoltSlashMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            BoltMark(size: size)
                .opacity(0.85)

            Path { path in
                path.move(to: CGPoint(x: size * 0.20, y: size * 0.15))
                path.addLine(to: CGPoint(x: size * 0.80, y: size * 0.85))
            }
            .stroke(style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// 安全锁
struct LockMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            // 锁身
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: size * 0.82, height: size * 0.58)
                .offset(y: size * 0.16)

            // 锁梁
            Path { path in
                path.addArc(
                    center: CGPoint(x: size * 0.5, y: size * 0.42),
                    radius: size * 0.25,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.55))
                path.move(to: CGPoint(x: size * 0.25, y: size * 0.42))
                path.addLine(to: CGPoint(x: size * 0.25, y: size * 0.55))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            // 锁孔
            Circle()
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(y: size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

/// 安全感叹盾牌
struct ShieldExclamationMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.12))
                path.addLine(to: CGPoint(x: size * 0.84, y: size * 0.24))
                path.addLine(to: CGPoint(x: size * 0.84, y: size * 0.55))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.5, y: size * 0.90),
                    control: CGPoint(x: size * 0.84, y: size * 0.78)
                )
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.16, y: size * 0.55),
                    control: CGPoint(x: size * 0.16, y: size * 0.78)
                )
                path.addLine(to: CGPoint(x: size * 0.16, y: size * 0.24))
                path.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            VStack(spacing: 1.6) {
                Capsule().frame(width: 1.6, height: size * 0.26)
                Circle().frame(width: 1.6, height: 1.6)
            }
            .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// 信息圆圈
struct InfoCircleMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: 1.6)
                .frame(width: size, height: size)

            VStack(spacing: 2) {
                Circle().frame(width: 1.6, height: 1.6)
                Capsule().frame(width: 1.6, height: size * 0.32)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 圆形圆弧辅助
private struct ArcShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}
