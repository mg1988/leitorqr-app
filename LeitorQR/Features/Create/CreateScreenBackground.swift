import SwiftUI

/// 创建页背景：纯色页面底 + 极细点阵底纹（呼应二维码）。不用任何渐变（11-27 用户要求），全部静态。
struct CreateScreenBackground: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Theme.Palette.background
                .ignoresSafeArea()

            Canvas { context, size in
                let spacing: CGFloat = 26
                let dotRadius: CGFloat = 1.0
                let dotColor = colorScheme == .dark
                    ? Color.white.opacity(0.04)
                    : Color.black.opacity(0.03)

                var x: CGFloat = spacing / 2
                while x < size.width {
                    var y: CGFloat = spacing / 2
                    while y < size.height {
                        let rect = CGRect(
                            x: x - dotRadius,
                            y: y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        y += spacing
                    }
                    x += spacing
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
