import SwiftUI
import TrinketCore

public extension HomesteadTint {
    var color: Color {
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
