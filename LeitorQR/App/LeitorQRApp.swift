import OSLog
import SwiftData
import SwiftUI

@main
struct LeitorQRApp: App {

    @StateObject private var subscriptions = SubscriptionManager()

    private let container: ModelContainer

    init() {
        #if DEBUG
        // 截图/验收用：启动时直接指定语言，不等用户进设置页点选。
        if let language = DebugLaunchOptions.language {
            LanguageManager.shared.select(language)
        }
        // 预置信任域名，验收风险卡降级为「已信任」。
        if !DebugLaunchOptions.whitelistSeed.isEmpty {
            RiskStore.whitelist = DebugLaunchOptions.whitelistSeed
        }
        #endif
        do {
            container = try ModelContainer(for: ScanRecord.self, RiskScanRecord.self)
            Self.protectStoreFiles()
        } catch {
            // 本机数据库损坏时退化为内存存储：App 仍可用，历史不跨启动保留。
            // 内存容器创建本身也可能失败，不能再用 try! 在 @main 构造期无诊断地崩掉。
            do {
                container = try ModelContainer(
                    for: ScanRecord.self, RiskScanRecord.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                Logger(subsystem: "com.leitorqr.app", category: "SwiftData")
                    .error("disk store unavailable, in-memory fallback: \(error.localizedDescription, privacy: .public)")
            } catch {
                fatalError("Não foi possível criar o contentor de dados: \(error)")
            }
        }
    }

    /// 给 SwiftData 存储文件显式设文件保护级别。
    /// 历史记录 rawValue 原样保存 Wi-Fi 密码等敏感负载。iOS 对 App 沙盒新文件的
    /// 默认级别就是 `completeUntilFirstUserAuthentication`，这里显式钉住该级别：
    /// 不依赖系统默认值，也防止日后有人改共享容器/迁移存储时悄悄降级。
    private static func protectStoreFiles() {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        for suffix in ["", "-wal", "-shm"] {
            let path = supportDir.appendingPathComponent("default.store\(suffix)").path
            guard fileManager.fileExists(atPath: path) else { continue }
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: path
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(subscriptions)
                .tint(Theme.Palette.primary)
                .task {
                    #if DEBUG
                    // 放在订阅检查之前：simctl 启动没有 StoreKit 配置，订阅那步可能很慢。
                    BarcodeDebugDump.runIfNeeded()
                    #endif
                    await subscriptions.start()
                }
        }
        .modelContainer(container)
    }
}
