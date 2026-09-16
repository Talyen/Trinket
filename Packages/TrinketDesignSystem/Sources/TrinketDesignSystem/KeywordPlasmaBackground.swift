import SwiftUI
import TrinketCore

public struct KeywordPlasmaBackground: View {
    let keywords: [Keyword]
    let focalYOffset: CGFloat
    let isMotionActive: Bool

    @Environment(\.isDecorativeMotionActive) private var isPresentationMotionActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = PlasmaClock()

    public init(keywords: [Keyword], focalYOffset: CGFloat = 75, isMotionActive: Bool = true) {
        self.keywords = keywords
        self.focalYOffset = focalYOffset
        self.isMotionActive = isMotionActive
    }

    private var isTimelinePaused: Bool {
        !isMotionActive || !isPresentationMotionActive || scenePhase != .active || reduceMotion
    }

    public var body: some View {
        Group {
            if !keywords.isEmpty {
                let resolved = Self.colors(for: keywords)
                if reduceMotion {
                    LinearGradient(
                        colors: [
                            resolved.primary.opacity(0.28),
                            resolved.secondary.opacity(0.18),
                            TrinketDesign.Colors.canvas,
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                } else {
                    singleSourceBody(primary: resolved.primary, secondary: resolved.secondary)
                }
            }
        }
        .onAppear { clock.setActive(!isTimelinePaused, at: Date()) }
        .onChange(of: isTimelinePaused) { _, paused in
            clock.setActive(!paused, at: Date())
        }
        .onDisappear { clock.setActive(false, at: Date()) }
    }

    private func singlePlasmaLayer(primary: Color, secondary: Color, center: CGPoint, size: CGSize, time: Float) -> some View {
        Rectangle()
            .fill(TrinketDesign.Colors.canvas)
            .colorEffect(ShaderLibrary.bundle(.module).shaderLiquidPlasma(
                .float2(Float(size.width), Float(size.height)),
                .float(time),
                .color(primary),
                .color(secondary),
                .float2(Float(center.x), Float(center.y)),
            ))
            .blendMode(.plusLighter)
            .frame(width: size.width, height: size.height)
    }

    private func singleSourceBody(primary: Color, secondary: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(clock.elapsed(at: timeline.date))
                let focalCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - focalYOffset)
                singlePlasmaLayer(
                    primary: primary,
                    secondary: secondary,
                    center: focalCenter,
                    size: geometry.size,
                    time: time,
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(reduceMotion ? nil : TrinketMotion.Content.fade, value: keywords)
    }

    nonisolated static func colors(for keywords: [Keyword]) -> (primary: Color, secondary: Color) {
        let firstStyle = keywords.first?.visualStyle
        let primary = firstStyle?.color ?? TrinketDesign.Colors.accent
        let secondary = keywords.count > 1 ? keywords[1].visualStyle.color : (firstStyle?.secondaryColor ?? primary)
        return (primary, secondary)
    }
}

extension KeywordPlasmaBackground {
    struct PlasmaClock {
        private var accumulated: TimeInterval = 0
        private var runningSince: Date?

        func elapsed(at date: Date) -> TimeInterval {
            accumulated + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
        }

        mutating func setActive(_ active: Bool, at date: Date) {
            if active {
                if runningSince == nil {
                    runningSince = date
                }
            } else if runningSince != nil {
                // Freeze the current shader phase and exclude time spent behind presentations.
                accumulated = elapsed(at: date)
                runningSince = nil
            }
        }
    }
}
