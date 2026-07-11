import SwiftUI
import TrinketCore

public extension HomesteadTint {
    var color: Color {
        switch self {
        case .orange:
            .orange
        case .green:
            .green
        case .yellow:
            .yellow
        case .mint:
            .mint
        case .cyan:
            .cyan
        case .indigo:
            .indigo
        case .blue:
            .blue
        }
    }
}
