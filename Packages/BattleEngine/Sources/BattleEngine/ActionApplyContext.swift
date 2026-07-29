import Foundation
import TrinketContent
import TrinketCore

/// Per-action context passed into effect handlers during `performAction`.
/// Keeps action-scoped coordination (such as paired direct damage) out of
/// `BattleState`.
public struct ActionApplyContext {
    public let pairedDirectDamage: [(Keyword, Int)]

    public init(pairedDirectDamage: [(Keyword, Int)] = []) {
        self.pairedDirectDamage = pairedDirectDamage
    }

    public func shouldSkipImmediateDoT(keyword: Keyword) -> Bool {
        pairedDirectDamage.contains { $0.0 == keyword }
    }
}
