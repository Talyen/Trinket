import SwiftUI

private struct ShineTextModifier: ViewModifier {
    let colors: [Color]
    @Environment(\.isDecorativeMotionActive) private var isMotionActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = DecorativeLoopClock()

    func body(content: Content) -> some View {
        if colors.isEmpty {
            content
        } else {
            let paused = reduceMotion || !isMotionActive || scenePhase != .active
            // Stops are phase-independent: build once per body evaluation,
            // not on every TimelineView tick.
            let sweepStops = textShineStops(colors: colors)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { context in
                // Freeze (don't snap to zero) so parking behind presentations
                // or toggling Reduce Motion resumes seamlessly like plasma.
                let phase = TrinketMotion.Shine.phase(
                    at: clock.elapsed(at: context.date),
                    period: TrinketMotion.Shine.textLoopPeriod,
                )
                content
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(stops: sweepStops),
                            startPoint: UnitPoint(x: 2 * phase - 2, y: 0.5),
                            endPoint: UnitPoint(x: 2 * phase + 2, y: 0.5),
                        ),
                    )
            }
            .onAppear { clock.setActive(!paused, at: Date()) }
            .onChange(of: paused) { _, isPaused in
                clock.setActive(!isPaused, at: Date())
            }
            .onDisappear { clock.setActive(false, at: Date()) }
        }
    }
}

private func textShineLoopColors(colors: [Color]) -> [Color] {
    var seen = Set<Color>()
    let unique = colors.filter { seen.insert($0).inserted }
    guard let first = unique.first else { return [] }
    let band = unique + [TrinketDesign.Colors.Overlay.paper]
    return band + band + [first]
}

private func textShineStops(colors: [Color]) -> [Gradient.Stop] {
    let looped = textShineLoopColors(colors: colors)
    guard looped.count > 1 else { return [] }
    let last = Double(looped.count - 1)
    return looped.enumerated().map { Gradient.Stop(color: $0.element, location: Double($0.offset) / last) }
}

public extension View {
    /// Raw shine renderer over explicit colors. For a `Shine` model value, use
    /// `shineText(_:)` in TrinketFeatureSupport instead.
    func trinketShineText(colors: [Color]) -> some View {
        modifier(ShineTextModifier(colors: colors))
    }
}
