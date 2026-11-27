import SwiftUI

/// PRO 入口的统一路由。
///
/// 为什么单独一个类型：付费墙在全项目只有 `RootTabView.fullScreenCover` 一处呈现
/// （两个 presentation 同页会互吞，曾导致结果页消失、相机永久暂停）。
/// 所以「点皇冠」不能在各页自己弹 sheet，必须回到根视图统一处理。
/// 已订阅时打开订阅管理（可取消），未订阅时走付费墙触发器的 featureGate。
@MainActor
final class ProPortal: ObservableObject {

    static let shared = ProPortal()

    /// 订阅管理（含取消订阅）是否呈现。由 RootTabView 挂的唯一 sheet 消费。
    @Published var isSubscriptionPresented = false

    private init() {}

    /// 页签右上角的皇冠按钮统一走这里。
    func openCrown(isPremium: Bool) {
        if isPremium {
            isSubscriptionPresented = true
        } else {
            PaywallTriggerManager.shared.triggerFeatureGate("nav.pro")
        }
    }
}
