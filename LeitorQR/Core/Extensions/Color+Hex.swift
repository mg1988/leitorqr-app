import SwiftUI
import UIKit

extension Color {
    /// 用一个十六进制值定义随浅色/深色模式自动切换的颜色。
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// 固定色（不随外观切换）。
    init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
