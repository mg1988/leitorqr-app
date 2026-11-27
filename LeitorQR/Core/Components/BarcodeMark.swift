import SwiftUI

/// 条形码小图标：用几条粗细不同的竖条画出来。
///
/// 不用 SF Symbol `barcode`：四个入口都是同一个符号，用户分不出 EAN-13 和 Code 39。
/// 用真实码制的疏密特征手绘——EAN 密集等宽、Code 39 宽窄分明——一眼能看出是不同格式，
/// 又不至于在小尺寸下糊成一片。
struct BarcodeMark: View {

    let kind: BarcodeKind
    var size: CGFloat = 24

    var body: some View {
        // 把条宽和空隙都换算成"模块"，整组正好铺满 size。
        let modules = pattern.reduce(0, +) + CGFloat(pattern.count - 1)
        let unit = modules > 0 ? size / modules : 1

        HStack(spacing: unit) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { _, width in
                Rectangle()
                    .frame(width: width * unit)
            }
        }
        .frame(width: size, height: size * 0.74)
    }

    /// 每个元素是一条黑条的宽度（模块数），条与条之间统一留 1 个模块的空。
    private var pattern: [CGFloat] {
        switch kind {
        case .ean13: return [1, 1, 2, 1, 1, 1, 2, 1, 1, 2, 1, 1]
        case .ean8: return [1, 2, 1, 1, 1, 2, 1, 1, 2]
        case .code128: return [1, 1, 2, 1, 1, 1, 1, 2, 1, 1, 1, 1, 2, 1]
        case .code39: return [1, 2, 1, 3, 1, 2, 1, 3]
        // 二维码制不走这个图标，兜底给一组等宽条。
        case .qr, .aztec, .pdf417: return [1, 1, 1, 1, 1, 1]
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach(BarcodeKind.oneDimensional) { kind in
            VStack(spacing: 6) {
                BarcodeMark(kind: kind, size: 28)
                    .foregroundStyle(Theme.Palette.primary)
                Text(kind.title).font(.caption2)
            }
        }
    }
    .padding()
}
