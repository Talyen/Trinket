import SwiftUI
import TrinketContent
import TrinketCore

extension HomesteadTint {
    public var color: Color {
        switch self {
        case .orange:
            return .orange
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .mint:
            return .mint
        case .cyan:
            return .cyan
        case .indigo:
            return .indigo
        case .blue:
            return .blue
        }
    }
}

extension HomesteadNodeDefinition {
    public var tint: Color {
        tintStyle.color
    }
}
