import SwiftUI
import UIKit

/// 极简高质感 Apple 级历史记录卡片（Apple-Grade Unified Card）：
/// - 纯粹统一构图（无内部分割线、无底部重复操作按钮）
/// - 56×56 pt 高清码图预览衬底与微角标
/// - 左图右文：语义化主标题、清晰内容摘要、元数据标签（码制、来源、时间）
/// - 点击整卡触发 Hero 缩放转场直达详情
/// - 长按呼出原生 ContextMenu 快捷操作（拷贝、分享、删除）
struct HistoryCardView: View {

    let record: ScanRecord
    /// 批量选择态：显示勾选圈、隐藏右侧箭头、点击改为切换选中。
    var isSelecting: Bool = false
    var isSelected: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // MARK: - 1. 左侧：勾选圈（选择态）或码图预览（常态）
            if isSelecting {
                ZStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? Theme.Palette.primary : Theme.Palette.textSecondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .accessibilityLabel(isSelected ? L10n.History.a11ySelected : L10n.History.a11yUnselected)
            } else {
                codeThumbnailPlatter
                    .frame(width: 56, height: 56)
            }

            // MARK: - 2. 中间：标题 + 摘要 + 元数据
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：主标题 + 备注微章
                HStack(spacing: 6) {
                    Text(record.trimmedNote ?? record.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)

                    if record.trimmedNote != nil {
                        Text(L10n.History.noteBadge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Theme.Palette.warning.opacity(0.15)))
                            .foregroundStyle(Theme.Palette.warning)
                    }

                    Spacer()
                }

                // 第二行：内容摘要 (单行截断)
                Text(record.displaySubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)

                // 第三行：元数据信息流 (码制格式 + 来源 + 时间)
                HStack(spacing: 6) {
                    // 码制胶囊
                    Text(badgeText)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(Theme.Palette.border.opacity(colorScheme == .dark ? 0.4 : 0.6))
                        )
                        .foregroundStyle(Theme.Palette.textSecondary)

                    // 来源标签
                    HStack(spacing: 3) {
                        Image(systemName: sourceIcon)
                            .font(.system(size: 9))
                        Text(record.source.localizedName)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.85))

                    Spacer()

                    // 时间戳
                    Text(timeText)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.75))
                }
                .padding(.top, 2)
            }

            // MARK: - 3. 右侧轻量引导箭头（选择态隐藏，避免误以为能进详情）
            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.35))
                    .padding(.trailing, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? Theme.Palette.primary.opacity(0.8)
                               : Theme.Palette.border.opacity(colorScheme == .dark ? 0.6 : 0.7),
                    lineWidth: isSelected ? 1.6 : 0.8
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
            radius: 8,
            x: 0,
            y: 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(action: onSelect) {
                Label(L10n.History.viewDetail, systemImage: "eye")
            }

            Button {
                copyRawValue()
            } label: {
                Label(L10n.History.copyContent, systemImage: "doc.on.doc")
            }

            if let img = record.regeneratedImage {
                ShareLink(
                    item: Image(uiImage: img),
                    preview: SharePreview(record.displayTitle, image: Image(uiImage: img))
                ) {
                    Label(L10n.History.shareImage, systemImage: "square.and.arrow.up")
                }
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label(L10n.History.deleteRecord, systemImage: "trash")
            }
        }
    }

    // MARK: - 左侧图标

    /// 扫描来的记录用「类型色图标块」：二维码小图人眼分不出差别，颜色 + 图标扫一眼就能分类。
    /// 自己生成的码保留真实缩略图（模板、Logo 本身就是用户要找的东西），右下角补一个类型色点。
    @ViewBuilder
    private var codeThumbnailPlatter: some View {
        if record.source == .generator, let kind = record.regenerableKind {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.Palette.border.opacity(0.6), lineWidth: 0.8)
                    )

                BarcodeThumbnail(
                    value: record.rawValue,
                    kind: kind,
                    style: record.savedStyle,
                    logo: record.savedLogo,
                    cacheID: record.id.uuidString,
                    side: 48
                )
                .padding(4)

                Image(systemName: record.contentType.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(Circle().fill(record.contentType.tint))
                    .overlay(Circle().strokeBorder(Theme.Palette.surface, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }
        } else {
            ContentTypeBadge(type: record.contentType, size: 48)
        }
    }

    // MARK: - 格式化辅助

    private var timeText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(record.createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: record.createdAt)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: record.createdAt)
        }
    }

    private var badgeText: String {
        if let format = record.barcodeFormat {
            return format.displayName
        }
        return record.contentType.localizedName
    }

    private var sourceIcon: String {
        switch record.source {
        case .camera: return "camera.fill"
        case .photos: return "photo.fill"
        case .generator: return "sparkles"
        }
    }

    private func copyRawValue() {
        // Wi-Fi 记录原文里带密码，走敏感剪贴板；其余内容保留普通复制。
        if record.contentType == .wifi {
            SensitivePasteboard.copy(record.rawValue)
        } else {
            UIPasteboard.general.string = record.rawValue
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
