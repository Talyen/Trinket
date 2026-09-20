import Foundation

/// Cases and scalar transforms are generated from Scripts/internal/content/modifiers.json.
public extension AffixModifier {
    func bumped(intDelta: Int, percentDelta: Double) -> AffixModifier? {
        if isPercent {
            let old = numericValue
            let new = old + percentDelta
            guard percentDelta > 0 || old > 0.01 + 1e-9 else { return nil }
            return mapPercent { _ in new }
        }
        let old = Int(numericValue)
        let new = old + intDelta
        guard intDelta > 0 || old > 1 else { return nil }
        return mapInt { _ in new }
    }
}
