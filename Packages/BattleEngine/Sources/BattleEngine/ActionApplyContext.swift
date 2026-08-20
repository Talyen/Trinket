import Foundation
import TrinketContent
import TrinketCore

/// Direct damage dealt in tandem with an applied status effect during an action.
public struct PairedDamage: Equatable, Sendable {
    public let keyword: Keyword
    public let amount: Int

    public init(keyword: Keyword, amount: Int) {
        self.keyword = keyword
        self.amount = amount
    }
}

/// Per-action context passed into effect handlers during `performAction`.
/// Keeps action-scoped coordination (such as paired direct damage) out of
/// `BattleState`.
public struct ActionApplyContext {
    public let pairedDirectDamage: [PairedDamage]

    public init(pairedDirectDamage: [PairedDamage] = []) {
        self.pairedDirectDamage = pairedDirectDamage
    }

    public func shouldSkipImmediateDoT(keyword: Keyword) -> Bool {
        pairedDirectDamage.contains { $0.keyword == keyword }
    }
}
