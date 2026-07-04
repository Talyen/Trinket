import TrinketContent
import TrinketCore
import TrinketPersistence


struct HomesteadProjectStatus {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    var isUnlocked: Bool {
        homestead.isUnlocked(definition)
    }

    var isComplete: Bool {
        homestead.isComplete(definition)
    }

    var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var canBuildOrUpgrade: Bool {
        isUnlocked && isAffordable && !isComplete
    }

    var actionTitle: String {
        guard let nextTier else { return "Complete" }
        return nextTier.tier == 1 ? "Build" : "Upgrade"
    }

    func balance(for amount: ResourceAmount) -> Int {
        homestead.balance(for: amount.resource, roster: roster)
    }

    func hasEnough(_ amount: ResourceAmount) -> Bool {
        balance(for: amount) >= amount.quantity
    }
}
