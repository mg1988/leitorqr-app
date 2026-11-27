import Foundation
import SwiftData

/// 一次链接特征核对的快照。只存 URL 与结论所需的最小字段，不存图片、不上传。
@Model
final class RiskScanRecord {
    @Attribute(.unique) var id: UUID
    var rawValue: String
    var host: String
    var levelRaw: String
    /// 命中的规则 key 列表（本地化时再转文案，避免把译文存进库）。
    var findingKeys: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawValue: String,
        host: String,
        level: QRRiskLevel,
        findingKeys: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawValue = rawValue
        self.host = host
        self.levelRaw = String(level.rawValue)
        self.findingKeys = findingKeys
        self.createdAt = createdAt
    }

    var level: QRRiskLevel {
        QRRiskLevel(rawValue: Int(levelRaw) ?? 0) ?? .low
    }

    convenience init(assessment: QRRiskAssessment, url: URL) {
        self.init(
            rawValue: url.absoluteString,
            host: url.host ?? url.absoluteString,
            level: assessment.level,
            findingKeys: assessment.findings.map(\.key)
        )
    }
}
