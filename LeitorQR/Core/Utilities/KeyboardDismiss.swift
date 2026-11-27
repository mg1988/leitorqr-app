import SwiftUI
import UIKit

/// 收起键盘。
///
/// 表单页输入框多、又没有"提交"这个动作可以顺带收键盘，用户填完就卡在键盘上——
/// 只能去拖列表（`scrollDismissesKeyboard` 还得先知道可以拖）。
/// 这里在键盘弹出时往导航栏右上角放一个「Concluído」，任何输入态都有一条明确出口。
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

private struct KeyboardDoneModifier: ViewModifier {

    let title: String
    @State private var keyboardVisible = false

    /// 调试开关：本机模拟器没有软键盘，靠它把按钮显示出来做视觉验收。
    private var isVisible: Bool {
        #if DEBUG
        if DebugLaunchOptions.forceKeyboardBar { return true }
        #endif
        return keyboardVisible
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isVisible {
                        // 只用图标：文字「Concluído」在自定义码表单里会和父层的「Fechar」
                        // 一起把标题挤成「Código personaliz…」。
                        Button(action: dismissKeyboard) {
                            ChevronDownMark(size: 16)
                                .foregroundStyle(Theme.Palette.primary)
                        }
                        .accessibilityLabel(title)
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: isVisible)
    }
}

extension View {

    /// 键盘弹出时在右上角出现「Concluído」。
    ///
    /// 没有用 `ToolbarItemGroup(placement: .keyboard)`：iOS 26 在键盘没起来的瞬间
    /// 会把这条工具栏浮在屏幕底部（接蓝牙键盘时尤其明显），留下一个孤零零的按钮。
    func keyboardDoneButton(_ title: String = L10n.Common.done) -> some View {
        modifier(KeyboardDoneModifier(title: title))
    }

    /// 点空白处收起键盘。
    ///
    /// 用 `simultaneousGesture` 而不是 `onTapGesture`：后者会和卡片里按钮的点击抢事件，
    /// 表现成"按钮要按两下"。
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { dismissKeyboard() }
        )
    }
}
