import TrinketContent
import TrinketCore

extension CombatantMaxValues {
    static func maximumManaBonus(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            guard case let .maximumManaBonus(amount) = active.effect else { return sum }
            return SaturatedArithmetic.saturatingAdd(sum, amount)
        }
    }
}
