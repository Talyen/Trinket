import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Low-count keyword-tinted particle bursts share one display clock and Canvas
/// per combatant pane. The display link pauses once every burst has expired.
struct KeywordBurstLayer: View {
    let requests: [KeywordBurstRequest]

    @State private var clockPaused = true

    private var burstClockID: Int {
        var hasher = Hasher()
        for request in requests {
            hasher.combine(request.id)
            hasher.combine(request.availableAt.timeIntervalSinceReferenceDate)
            hasher.combine(request.expiresAt.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    var body: some View {
        Group {
            if !requests.isEmpty {
                TimelineView(.animation(paused: clockPaused)) { context in
                    Canvas(rendersAsynchronously: true) { canvas, size in
                        for request in requests {
                            draw(request, at: context.date, in: &canvas, size: size)
                        }
                    }
                }
                .task(id: burstClockID) {
                    clockPaused = false
                    guard let latestExpiry = requests.map(\.expiresAt).max() else {
                        clockPaused = true
                        return
                    }
                    let delay = latestExpiry.timeIntervalSince(.now)
                    if delay > 0 {
                        try? await Task.sleep(for: .seconds(delay))
                    }
                    guard !Task.isCancelled else { return }
                    clockPaused = true
                }
            }
        }
        .allowsHitTesting(false)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.keywordBurst,
            isActive: !requests.isEmpty
        )
    }

    private func draw(
        _ request: KeywordBurstRequest,
        at date: Date,
        in canvas: inout GraphicsContext,
        size: CGSize
    ) {
        let elapsed = date.timeIntervalSince(request.availableAt)
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
            let diameter = radius * 2

            canvas.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: diameter,
                    height: diameter
                )),
                with: .color(color.opacity(opacity))
            )
        }
    }
}
