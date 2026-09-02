import SwiftUI
import TrinketCore
import TrinketDesignSystem

public enum Shine: Equatable, Sendable {
    case none
    case keywords([Keyword])
    case colors([Color])
    case unique
    case corruption

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.unique, .unique), (.corruption, .corruption):
            true
        case let (.keywords(a), .keywords(b)):
            a == b
        case (.colors, .colors):
            false
        default:
            false
        }
    }

    public var textColors: [Color] {
        switch self {
        case .none:
            []
        case let .keywords(keywords):
            keywordColors(keywords)
        case let .colors(colors):
            colors
        case .unique:
            UniqueShine.textColors
        case .corruption:
            CorruptionShine.textColors
        }
    }

    public var borderColors: [Color]? {
        switch self {
        case .none:
            nil
        case let .keywords(keywords) where keywords.isEmpty:
            nil
        case let .keywords(keywords):
            keywords.map(\.visualStyle.color)
        case let .colors(colors) where colors.isEmpty:
            nil
        case let .colors(colors):
            colors
        case .unique:
            UniqueShine.borderColors
        case .corruption:
            CorruptionShine.borderColors
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .none: true
        case let .keywords(k): k.isEmpty
        case let .colors(c): c.isEmpty
        case .unique, .corruption: false
        }
    }

    public static func keyword(_ keyword: Keyword?) -> Self {
        guard let keyword else { return .none }
        return Self.keywords([keyword])
    }
}

private func keywordColors(_ keywords: [Keyword]) -> [Color] {
    keywords.flatMap { [$0.visualStyle.color, $0.visualStyle.secondaryColor] }
}

private struct ShineTextModifier: ViewModifier {
    let shine: Shine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let colors = shine.textColors
        if colors.isEmpty {
            content
        } else {
            let sweepStops = textShineStops(colors: colors)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let phase = reduceMotion
                    ? 0
                    : TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate)
                content
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(stops: sweepStops),
                            startPoint: UnitPoint(x: phase - 1, y: 0.5),
                            endPoint: UnitPoint(x: phase + 1, y: 0.5),
                        ),
                    )
            }
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

public enum CorruptionShine {
    public static let textColors: [Color] = [
        TrinketDesign.Colors.destructive,
        TrinketDesign.Colors.destructive.opacity(0.55),
    ]
    public static let borderColors: [Color] = [
        TrinketDesign.Colors.destructive,
    ]
}

public enum UniqueShine {
    public static let textColors: [Color] = [
        TrinketDesign.Colors.warning,
        TrinketDesign.Colors.warning.opacity(0.55),
    ]
    public static let borderColors: [Color] = [
        TrinketDesign.Colors.warning,
    ]
}

public extension View {
    func shineText(_ shine: Shine) -> some View {
        modifier(ShineTextModifier(shine: shine))
    }
}
