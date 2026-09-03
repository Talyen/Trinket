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
        Group {
            switch plasmaContent {
            case .paused:
                pausedFallback
            case let .multi(active):
                multiSourceBody(active)
            case .single:
                singleSourceBody
            case .empty:
                EmptyView()
            }
        }
        .onAppear { startDate = Date() }
    }

    private enum PlasmaContent {
        case paused
        case multi([Source])
        case single
        case empty
    }

    private var plasmaContent: PlasmaContent {
        if isTimelinePaused {
            return .paused
        }
        if let sources {
            let active = sources.filter { !$0.keywords.isEmpty }
            return active.isEmpty ? .empty : .multi(active)
        }
        return keywords.isEmpty ? .empty : .single
    }

    @ViewBuilder
    private var pausedFallback: some View {
        if let fallbackColors = pausedColors {
            LinearGradient(
                colors: [
                    fallbackColors.primary.opacity(0.28),
                    fallbackColors.secondary.opacity(0.18),
                    TrinketDesign.Colors.canvas,
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var pausedColors: (primary: Color, secondary: Color)? {
        if let sources {
            guard let first = sources.first(where: { !$0.keywords.isEmpty }) else { return nil }
            return Self.colors(for: first.keywords)
        }
        guard !keywords.isEmpty else { return nil }
        return Self.colors(for: keywords)
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

    private var singleSourceBody: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let resolved = Self.colors(for: Array(keywords.prefix(2)))
                let focalCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - focalYOffset)
                singlePlasmaLayer(
                    primary: resolved.primary,
                    secondary: resolved.secondary,
                    center: focalCenter,
                    size: geometry.size,
                    time: time,
                )
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(reduceMotion ? nil : TrinketMotion.Content.fade, value: keywords)
        .animation(nil, value: isMotionActive)
        .animation(nil, value: reduceMotion)
    }

    private func multiSourceBody(_ activeSources: [Source]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isTimelinePaused)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                if activeSources.count == 1, let first = activeSources.first {
                    let firstColors = Self.colors(for: first.keywords)
                    let firstCenter = Self.center(for: first, in: geometry.size)
                    singlePlasmaLayer(
                        primary: firstColors.primary,
                        secondary: firstColors.secondary,
                        center: CGPoint(x: CGFloat(firstCenter.x), y: CGFloat(firstCenter.y)),
                        size: geometry.size,
                        time: time,
                    )
                } else if let first = activeSources.first, activeSources.count == 2 {
                    let second = activeSources[1]
                    let firstColors = Self.colors(for: first.keywords)
                    let secondColors = Self.colors(for: second.keywords)
                    let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                    let firstCenter = Self.center(for: first, in: geometry.size)
                    let secondCenter = Self.center(for: second, in: geometry.size)
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

    nonisolated static func colors(for keywords: [Keyword]) -> (primary: Color, secondary: Color) {
        let limited = Array(keywords.prefix(2))
        let primary = limited.first?.visualStyle.color ?? TrinketDesign.Colors.accent
        let secondary = limited.count > 1 ? limited[1].visualStyle.color : (limited.first?.visualStyle.secondaryColor ?? primary)
        return (primary, secondary)
    }

    nonisolated static func center(for source: Source, in size: CGSize) -> float2 {
        float2(Float(source.focalPoint.x * size.width), Float(source.focalPoint.y * size.height))
    }
}
