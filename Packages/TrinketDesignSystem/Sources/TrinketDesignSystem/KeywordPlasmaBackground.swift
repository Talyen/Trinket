import SwiftUI
import TrinketCore

public struct KeywordPlasmaBackground: View {
    let keywords: [Keyword]
    let focalYOffset: CGFloat
    let isMotionActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    public init(keywords: [Keyword], focalYOffset: CGFloat = 75, isMotionActive: Bool = true) {
        self.keywords = keywords
        self.focalYOffset = focalYOffset
        self.isMotionActive = isMotionActive
    }

    private var isTimelinePaused: Bool {
        !isMotionActive || reduceMotion
    }

    public var body: some View {
        Group {
            if !keywords.isEmpty {
                let resolved = Self.colors(for: keywords)
                if isTimelinePaused {
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
        .onAppear { startDate = Date() }
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
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
