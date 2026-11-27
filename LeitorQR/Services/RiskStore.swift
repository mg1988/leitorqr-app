import Foundation
import OSLog
import SwiftData

/// 安全风险相关的数据：白名单（UserDefaults）与核对历史（SwiftData）。
/// 全部端侧，不联网。白名单命中后风险卡降级为「已信任」，不再当作可疑。
enum RiskStore {

    /// 付费用户核对历史的保留上限，防止无限增长。
    static let historyLimit = 200

    private static let whitelistKey = "security.whitelist.domains"
    private static let logger = Logger(subsystem: "com.leitorqr.app", category: "RiskStore")

    // MARK: - 白名单

    static var whitelist: [String] {
        get {
            (UserDefaults.standard.array(forKey: whitelistKey) as? [String]) ?? []
        }
        set {
            UserDefaults.standard.set(Array(Set(newValue)).sorted(), forKey: whitelistKey)
        }
    }

    /// 域名精确匹配，或作为白名单域名的子域。`example.com` 信任 `shop.example.com`。
    static func isTrusted(_ host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return whitelist.contains { entry in
            normalized == entry || normalized.hasSuffix(".\(entry)")
        }
    }

    @discardableResult
    static func addToWhitelist(_ host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidDomain(normalized), !isTrusted(normalized) else { return false }
        whitelist.append(normalized)
        return true
    }

    static func removeFromWhitelist(_ host: String) {
        whitelist.removeAll { $0 == host.lowercased() }
    }

    /// 只接受域名形式，不存 URL / 路径 / 通配符，避免白名单被写成 `*` 或整段链接。
    private static func isValidDomain(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 253, !value.contains(" "),
              !value.contains("/"), !value.contains(":"), !value.contains("*"),
              value.contains("."),
              let labels = Optional(value.split(separator: ".").map(String.init)),
              labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty && $0 == $0.lowercased() }) else { return false }
        // 公共后缀本身（co.uk / com.br …）不能入白名单：isTrusted 按「自身 + 全部子域」
        // 命中，存一个后缀等于把整个 TLD 下的所有域都当成可信、自动放行。
        guard !isPublicSuffix(labels) else { return false }
        return labels.allSatisfy { label in
            label.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0.value == 45 }
        }
    }

    /// 常见多级公共后缀（取自 Public Suffix List 的高频项）。
    /// 判定规则：域名最后两段命中此表即视为公共后缀。
    private static let multiLevelPublicSuffixes: Set<String> = [
        // 英国
        "co.uk", "org.uk", "ac.uk", "gov.uk", "me.uk", "net.uk", "ltd.uk", "plc.uk",
        // 巴西/拉美
        "com.br", "net.br", "org.br", "gov.br", "com.mx", "com.ar", "com.co", "com.pe", "com.cl",
        // 亚太
        "com.au", "net.au", "org.au", "co.nz", "net.nz", "org.nz", "co.jp", "or.jp", "ne.jp",
        "com.cn", "net.cn", "org.cn", "gov.cn", "com.hk", "com.tw", "com.sg", "co.kr", "or.kr",
        "co.in", "net.in", "org.in", "co.id", "com.my", "com.ph", "com.vn", "co.th", "or.th",
        // 其他
        "co.za", "org.za", "com.tr", "com.eg", "co.il", "org.il", "com.sa", "com.ua", "com.pl",
        "co.at", "co.hu", "co.gr", "com.pt", "com.es", "com.it", "com.fr", "com.de"
    ]

    private static func isPublicSuffix(_ labels: [String]) -> Bool {
        guard labels.count >= 2 else { return false }
        let tail = labels.suffix(2).joined(separator: ".")
        return multiLevelPublicSuffixes.contains(tail)
    }

    // MARK: - 核对历史

    @discardableResult
    static func record(assessment: QRRiskAssessment, url: URL, in context: ModelContext) -> Bool {
        let entry = RiskScanRecord(assessment: assessment, url: url)
        context.insert(entry)
        trim(in: context)
        do {
            try context.save()
            return true
        } catch {
            logger.error("save risk scan failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func clearHistory(in context: ModelContext) {
        do {
            try context.delete(model: RiskScanRecord.self)
            try context.save()
        } catch {
            logger.error("clear risk history failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 只保留最近 historyLimit 条。SwiftData 没有内建 fetchLimit 删除，手动按时间裁。
    private static func trim(in context: ModelContext) {
        let all: [RiskScanRecord]
        do {
            all = try context.fetch(FetchDescriptor<RiskScanRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        } catch {
            logger.error("fetch risk history failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard all.count > historyLimit else { return }
        for record in all.dropFirst(historyLimit) { context.delete(record) }
    }
}
