import SwiftUI
import TrinketContent
import TrinketDesignSystem

extension Combatant {
    var healthBarColor: Color {
        switch role {
        case .hero, .pet: return TrinketDesign.Colors.health
        case .enemy: return Color.red
        }
    }
}
