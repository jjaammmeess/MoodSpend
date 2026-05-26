import SwiftUI

struct FlowLayout: Layout {
    enum HorizontalAlignment {
        case leading
        case center
    }

    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 10
    var alignment: HorizontalAlignment = .leading

    private struct Line {
        var subviewIndices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        guard !subviews.isEmpty else { return .zero }

        let rows = computeLines(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        if let proposedWidth = proposal.width {
            return CGSize(width: min(width, proposedWidth), height: height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let rows = computeLines(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for (rowIndex, row) in rows.enumerated() {
            let startX: CGFloat = {
                switch alignment {
                case .leading:
                    return bounds.minX
                case .center:
                    return bounds.minX + max(0, (bounds.width - row.width) / 2)
                }
            }()

            var x = startX
            for index in row.subviewIndices {
                let subview = subviews[index]
                let size = measuredSize(for: subview, maxWidth: bounds.width)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += row.height
            if rowIndex < rows.count - 1 {
                y += lineSpacing
            }
        }
    }

    private func measuredSize(for subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        // Intrinsic width for line-breaking; measuring at full row width underestimates pills.
        let intrinsic = subview.sizeThatFits(.unspecified)
        if intrinsic.width > 0, intrinsic.height > 0 {
            if maxWidth.isFinite, intrinsic.width > maxWidth {
                let constrained = subview.sizeThatFits(
                    ProposedViewSize(width: maxWidth, height: nil)
                )
                if constrained.width > 0, constrained.height > 0 {
                    return constrained
                }
            }
            return intrinsic
        }
        let fit = subview.sizeThatFits(
            ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)
        )
        if fit.width > 0, fit.height > 0 {
            return fit
        }
        return subview.sizeThatFits(.unspecified)
    }

    private func computeLines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var rows: [Line] = []
        var currentIndices: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        func flushLine() {
            guard !currentIndices.isEmpty else { return }
            let trailingSpacing = CGFloat(max(0, currentIndices.count - 1)) * spacing
            rows.append(
                Line(
                    subviewIndices: currentIndices,
                    width: currentWidth - trailingSpacing,
                    height: currentHeight
                )
            )
            currentIndices = []
            currentWidth = 0
            currentHeight = 0
        }

        for (index, subview) in subviews.enumerated() {
            let size = measuredSize(for: subview, maxWidth: maxWidth)
            let addedWidth = currentIndices.isEmpty ? size.width : spacing + size.width
            let candidateWidth = currentWidth + addedWidth

            if candidateWidth > maxWidth, !currentIndices.isEmpty {
                flushLine()
                currentIndices = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentIndices.append(index)
                currentWidth = candidateWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        flushLine()
        return rows
    }
}
