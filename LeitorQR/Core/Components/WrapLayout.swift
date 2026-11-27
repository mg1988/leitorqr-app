import SwiftUI

/// 排不下就换行，行内左对齐。
///
/// 用来替代横向滚动：一排胶囊滑出屏幕时，最后一项会被切成半个字，
/// 用户根本看不出后面还有选项。换行则把所有选项一次摆出来。
struct WrapLayout: Layout {

    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let candidate = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.indices.isEmpty, candidate > maxWidth {
                result.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = candidate
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}
