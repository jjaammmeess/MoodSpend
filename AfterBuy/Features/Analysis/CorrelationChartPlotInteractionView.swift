import SwiftUI
import UIKit

/// Plot overlay that scrubs on horizontal pans and taps, without blocking vertical `ScrollView` scrolling.
struct CorrelationChartPlotInteractionView: UIViewRepresentable {
    let plotRect: CGRect
    let onSelectPlotX: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectPlotX: onSelectPlotX)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.plotRect = plotRect
        context.coordinator.onSelectPlotX = onSelectPlotX
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var plotRect: CGRect
        var onSelectPlotX: (CGFloat, CGFloat) -> Void
        private var lockedHorizontal = false
        private var lockedVertical = false

        init(plotRect: CGRect = .zero, onSelectPlotX: @escaping (CGFloat, CGFloat) -> Void) {
            self.plotRect = plotRect
            self.onSelectPlotX = onSelectPlotX
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            applySelection(at: recognizer.location(in: recognizer.view))
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            switch recognizer.state {
            case .began:
                lockedHorizontal = false
                lockedVertical = false
            case .changed:
                if !lockedHorizontal, !lockedVertical {
                    let horizontal = abs(translation.x)
                    let vertical = abs(translation.y)
                    if horizontal >= 8, horizontal >= vertical {
                        lockedHorizontal = true
                    } else if vertical >= 8, vertical > horizontal {
                        lockedVertical = true
                    }
                }
                if lockedHorizontal {
                    applySelection(at: recognizer.location(in: recognizer.view))
                }
            case .ended, .cancelled, .failed:
                if lockedHorizontal {
                    applySelection(at: recognizer.location(in: recognizer.view))
                }
                lockedHorizontal = false
                lockedVertical = false
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func applySelection(at location: CGPoint) {
            guard plotRect.width > 0, plotRect.contains(location) else { return }
            onSelectPlotX(location.x - plotRect.minX, plotRect.width)
        }
    }
}
