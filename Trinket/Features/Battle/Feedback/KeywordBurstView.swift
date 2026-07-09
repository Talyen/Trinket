import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Low-count keyword-tinted particle burst rendered with Canvas.
struct KeywordBurstView: View {
    let request: KeywordBurstRequest
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation(paused: false)) { context in
                let elapsed = context.date.timeIntervalSince(request.availableAt)
                Canvas { canvas, size in
                    guard elapsed >= 0, elapsed < 0.45 else { return }
                    let progress = min(max(elapsed / 0.45, 0), 1)
                    let color = request.keyword.visualStyle.color
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)

                    for index in 0 ..< request.particleCount {
                        let noise = CombatFeedbackLayout.unitNoise(seed: request.seed &+ index &* 17)
                        let angle = Double(noise) * .pi * 2
                        let distance = 8 + Double(progress) * (18 + Double(index) * 3)
                        let x = center.x + CGFloat(cos(angle) * distance)
                        let y = center.y + CGFloat(sin(angle) * distance) - CGFloat(progress * 12)
                        let radius = max(1.2, 3.2 * (1 - progress))
                        let opacity = Double(1 - progress) * 0.85

                        var path = Path()
                        path.addEllipse(in: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        ))
                        canvas.fill(path, with: .color(color.opacity(opacity)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
