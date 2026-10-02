import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct KeywordShineBorder: View {
    public var shine: Shine
    public var cornerRadius: CGFloat = TrinketDesign.Corners.card
    public var lineWidth: CGFloat = 2
    public var isMotionActive: Bool = true

    public init(
        shine: Shine,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true,
    ) {
        self.shine = shine
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.isMotionActive = isMotionActive
    }

    public var body: some View {
        let colors = shine.borderColors ?? []
        Group {
            if colors.isEmpty {
                EmptyView()
            } else {
                BorderTimeline(
                    colors: colors,
                    cornerRadius: cornerRadius,
                    lineWidth: lineWidth,
                    isMotionActive: isMotionActive,
                )
            }
        }
    }
}

private struct BorderTimeline: View {
    let colors: [Color]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let isMotionActive: Bool
    @Environment(\.isDecorativeMotionActive) private var isPresentationMotionActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motionEnabled = isMotionActive && isPresentationMotionActive && scenePhase == .active && !reduceMotion
        let gradient = Gradient(stops: gradientStops(for: colors, motionEnabled: motionEnabled))
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !motionEnabled)) { context in
            let angle = motionEnabled
                ? TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
                : 0
            KeywordShineBorderStroke(
                gradient: gradient,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                angle: angle,
            )
        }
        .allowsHitTesting(false)
        .animation(nil, value: isMotionActive)
    }

    private func gradientStops(for colors: [Color], motionEnabled: Bool) -> [Gradient.Stop] {
        guard let base = colors.first else { return [] }
        if colors.count == 1 {
            return Shine.stops(for: base, motionEnabled: motionEnabled)
        }

        var looped = colors
        looped.append(looped[0])
        let count = looped.count - 1
        var stops: [Gradient.Stop] = []
        for i in 0 ... count {
            let loc = Double(i) / Double(count)
            stops.append(.init(color: looped[i], location: loc))
        }
        return stops
    }
}

private struct KeywordShineBorderStroke: View {
    let gradient: Gradient
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let angle: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(TrinketDesign.Colors.panel, lineWidth: lineWidth)
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let diameter = (width * width + height * height).squareRoot()
                AngularGradient(gradient: gradient, center: .center)
                    .frame(width: diameter, height: diameter)
                    .drawingGroup()
                    .rotationEffect(.degrees(angle))
                    .position(x: width / 2, y: height / 2)
            }
            .mask {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(TrinketDesign.Colors.Overlay.paper, lineWidth: lineWidth)
            }
        }
    }
}

public extension View {
    @ViewBuilder
    func shineBorder(
        _ shine: Shine,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true,
    ) -> some View {
        if !shine.isEmpty {
            overlay {
                KeywordShineBorder(
                    shine: shine,
                    cornerRadius: cornerRadius,
                    lineWidth: lineWidth,
                    isMotionActive: isMotionActive,
                )
            }
        } else {
            self
        }
    }
}
