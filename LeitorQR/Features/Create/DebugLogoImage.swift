#if DEBUG
import UIKit

/// 仅 Debug：合成一张"用户导入的照片"，用来验收圆形裁剪与 aspect fill。
///
/// 自动化点不了系统选图器，所以用一张带横向渐变、偏心白圆和底部黑条的图代替：
/// 圆的四个角有没有被削掉、底部黑条有没有被拉伸，一眼就能看出来。
enum DebugLogoImage {

    static func make(side: CGFloat = 512) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.98, green: 0.55, blue: 0.25, alpha: 1).cgColor,
                UIColor(red: 0.85, green: 0.20, blue: 0.35, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: side, y: side),
                    options: []
                )
            }

            UIColor.white.withAlphaComponent(0.9).setFill()
            cg.fillEllipse(
                in: CGRect(
                    x: side * 0.28,
                    y: side * 0.28,
                    width: side * 0.44,
                    height: side * 0.44
                )
            )

            UIColor.black.setFill()
            cg.fill(CGRect(x: 0, y: side - 40, width: side, height: 40))
        }
    }
}
#endif
