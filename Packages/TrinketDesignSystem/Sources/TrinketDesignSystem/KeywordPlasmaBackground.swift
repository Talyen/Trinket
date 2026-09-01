import simd
import SwiftUI
import TrinketCore

public struct KeywordPlasmaBackground: View {
    public struct Source {
        public let keywords: [Keyword]
        public let focalPoint: UnitPoint

        public init(keywords: [Keyword], focalPoint: UnitPoint) {
            self.keywords = keywords
            self.focalPoint = focalPoint
        }
    }

    let keywords: [Keyword]
    let focalYOffset: CGFloat
    let isMotionActive: Bool
    let sources: [Source]?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    public init(keywords: [Keyword], focalYOffset: CGFloat = 75, isMotionActive: Bool = true) {
        self.keywords = keywords
        self.focalYOffset = focalYOffset
        self.isMotionActive = isMotionActive
        sources = nil
    }

    public init(sources: [Source], isMotionActive: Bool = true) {
        precondition(sources.count <= 2, "KeywordPlasmaBackground supports at most 2 sources")
        keywords = []
        focalYOffset = 0
        self.isMotionActive = isMotionActive
        self.sources = Array(sources.prefix(2))
    }

    private var isTimelinePaused: Bool {
        !isMotionActive || reduceMotion
    }

    public var body: some View {
        if let sources {
            let active = sources.filter { !$0.keywords.isEmpty }
            if !active.isEmpty {
                multiSourceBody(active)
            }
        } else if !keywords.isEmpty {
            singleSourceBody
        }
    }

    private var singleSourceBody: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let colors = colors(for: Array(keywords.prefix(2)))
                let focalCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - focalYOffset)
                let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                let center = float2(Float(focalCenter.x), Float(focalCenter.y))
                Rectangle()
                    .fill(TrinketDesign.Colors.canvas)
                    .colorEffect(ShaderLibrary.bundle(.module).shaderLiquidPlasma(
                        .float2(size.x, size.y),
                        .float(time),
                        .color(colors.primary),
                        .color(colors.secondary),
                        .float2(center.x, center.y),
                    ))
                    .blendMode(.plusLighter)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: keywords) { _, _ in startDate = Date() }
        .animation(reduceMotion ? nil : TrinketMotion.Content.fade, value: keywords)
        .animation(nil, value: isMotionActive)
        .animation(nil, value: reduceMotion)
    }

    private func multiSourceBody(_ activeSources: [Source]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                if activeSources.count == 1, let first = activeSources.first {
                    let firstColors = colors(for: first.keywords)
                    let firstCenter = center(for: first, in: geometry.size)
                    let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                    Rectangle()
                        .fill(TrinketDesign.Colors.canvas)
                        .colorEffect(ShaderLibrary.bundle(.module).shaderLiquidPlasma(
                            .float2(size.x, size.y),
                            .float(time),
                            .color(firstColors.primary),
                            .color(firstColors.secondary),
                            .float2(firstCenter.x, firstCenter.y),
                        ))
                        .blendMode(.plusLighter)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if let first = activeSources.first, activeSources.count == 2 {
                    let second = activeSources[1]
                    let firstColors = colors(for: first.keywords)
                    let secondColors = colors(for: second.keywords)
                    let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                    let firstCenter = center(for: first, in: geometry.size)
                    let secondCenter = center(for: second, in: geometry.size)
                    Rectangle()
                        .fill(TrinketDesign.Colors.canvas)
                        .colorEffect(
                            ShaderLibrary.bundle(.module).shaderDualLiquidPlasma(
                                .float2(size.x, size.y),
                                .float(time),
                                .float(2),
                                .color(firstColors.primary),
                                .color(firstColors.secondary),
                                .float2(firstCenter.x, firstCenter.y),
                                .color(secondColors.primary),
                                .color(secondColors.secondary),
                                .float2(secondCenter.x, secondCenter.y),
                            ),
                        )
                        .blendMode(.plusLighter)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(nil, value: isMotionActive)
        .animation(nil, value: reduceMotion)
    }

    private func colors(for keywords: [Keyword]) -> (primary: Color, secondary: Color) {
        let limited = Array(keywords.prefix(2))
        let primary = limited.first?.visualStyle.color ?? TrinketDesign.Colors.accent
        let secondary = limited.count > 1 ? limited[1].visualStyle.color : (limited.first?.visualStyle.secondaryColor ?? primary)
        return (primary, secondary)
    }

    private func center(for source: Source, in size: CGSize) -> float2 {
        float2(Float(source.focalPoint.x * size.width), Float(source.focalPoint.y * size.height))
    }
}
