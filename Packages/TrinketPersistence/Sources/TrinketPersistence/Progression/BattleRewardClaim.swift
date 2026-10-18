import TrinketContent

/// A transient, single-outcome claim issued by the save that launched a battle.
/// Copies of a registration share consumption; refused writes leave it available.
@MainActor
public final class BattleRewardClaim {
    private weak var store: PlayerSaveStore?
    private let worldSeed: UInt64
    private let labyrinthSeed: UInt64
    private let generation: UInt64
    let destination: BattleCompletionDestination?
    let enemyID: String?
    public private(set) var completedResearchIDs: [String] = []
    private let heroID: String
    private let companionID: String
    private(set) var isConsumed = false

    init(store: PlayerSaveStore, destination: BattleCompletionDestination?, heroID: String, companionID: String, enemyID: String? = nil) {
        self.enemyID = enemyID
        self.store = store
        worldSeed = store.worldSeed
        labyrinthSeed = store.labyrinth.worldSeed
        generation = store.sessionGeneration
        self.destination = destination
        self.heroID = heroID
        self.companionID = companionID
    }

    public func isCurrent(in store: PlayerSaveStore) -> Bool {
        guard self.store === store, worldSeed == store.worldSeed,
              generation == store.sessionGeneration
        else { return false }
        if case .labyrinth = destination {
            return labyrinthSeed == store.labyrinth.worldSeed
        }
        return true
    }

    func party(in save: PlayerSave) -> (hero: Combatant, companion: Combatant)? {
        guard let hero = GameContent.hero(matching: heroID), save.roster.isHeroUnlocked(heroID),
              let companion = GameContent.companion(matching: companionID), save.roster.isCompanionUnlocked(companionID)
        else { return nil }
        return (hero, companion)
    }

    func consume(completedResearchIDs: [String] = []) {
        self.completedResearchIDs = completedResearchIDs
        isConsumed = true
    }
}
