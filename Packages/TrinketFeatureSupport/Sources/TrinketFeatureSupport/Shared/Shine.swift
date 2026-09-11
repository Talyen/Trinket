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
        case let (.colors(a), .colors(b)):
            a == b
        default:
            false
        }
    }

    public static let uniqueBorderColors: [Color] = [
        TrinketDesign.Colors.warning,
    ]

    public static let corruptionBorderColors: [Color] = [
        TrinketDesign.Colors.destructive,
    ]

    public static func stops(for base: Color, motionEnabled: Bool) -> [Gradient.Stop] {
        if !motionEnabled {
            return [
                .init(color: base, location: 0),
                .init(color: base, location: 0.5),
                .init(color: base, location: 1),
            ]
        }
        let highlight = TrinketDesign.Colors.Overlay.paper
        return [
            .init(color: base, location: 0),
            .init(color: base, location: 0.28),
            .init(color: highlight, location: 0.4),
            .init(color: base, location: 0.5),
            .init(color: base, location: 0.72),
            .init(color: base, location: 1),
        ]
    }

    public var colors: [Color]? {
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
            Self.uniqueBorderColors
        case .corruption:
            Self.corruptionBorderColors
        }
    }

    public var textColors: [Color] {
        colors ?? []
    }

    public var borderColors: [Color]? {
        colors
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

extension Shine {
    static func itemText(colors: [Color]) -> Self {
        guard !colors.isEmpty else { return .none }
        return .colors(colors.flatMap { [$0, $0.opacity(0.55)] })
    }
}

public extension View {
    func shineText(_ shine: Shine) -> some View {
        trinketShineText(colors: shine.textColors)
    }
}
