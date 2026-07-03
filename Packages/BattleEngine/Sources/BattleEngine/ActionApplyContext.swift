import Foundation
import TrinketCore
import TrinketContent

/// Per-action context passed into effect handlers during `performAction`.
/// Keeps action-scoped coordination (such as paired direct damage) out of
/// `BattleEngineContext`.
public struct ActionApplyContext {
    public let pairedDirectDamage: [(Keyword, Int)]

    public init(pairedDirectDamage: [(Keyword, Int)] = []) {
        self.pairedDirectDamage = pairedDirectDamage
    }

    public func shouldSkipImmediateDoT(potency: Int, keyword: Keyword) -> Bool {
        pairedDirectDamage.contains(where: { $0 == (keyword, potency) })
    }
}
