import Foundation

/// Per-action context passed into effect handlers during `performAction`.
/// Keeps action-scoped coordination (such as paired direct damage) out of
/// `BattleEngineContext`.
struct ActionApplyContext {
    let pairedDirectDamage: [(Keyword, Int)]

    init(pairedDirectDamage: [(Keyword, Int)] = []) {
        self.pairedDirectDamage = pairedDirectDamage
    }

    func shouldSkipImmediateDoT(potency: Int, keyword: Keyword) -> Bool {
        pairedDirectDamage.contains(where: { $0 == (keyword, potency) })
    }
}
