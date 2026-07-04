import SwiftUI

enum BattleOutcome: Equatable {
    case ongoing
    case victory
    case defeat
}

@MainActor
@Observable
final class BattleRun {
    private(set) var state: BattleState
    var activeFeedbackEvents: [ActionEvent] = []
    private var feedbackDisplayedAt: [Int: Date] = [:]

    let configuration: ActiveBattleConfiguration

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
        state = BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max)
        )
    }

    var log: [LogEntry] {
        state.log
    }

    var hero: Combatant {
        state.hero
    }

    var pet: Combatant {
        state.pet
    }

    var enemy: Combatant {
        state.enemy
    }

    var heroHealth: Int {
        state.health(of: state.hero)
    }

    var petHealth: Int {
        state.health(of: state.pet)
    }

    var enemyHealth: Int {
        state.health(of: state.enemy)
    }

    var heroMana: Int {
        state.mana(of: state.hero)
    }

    var petMana: Int {
        state.mana(of: state.pet)
    }

    var heroMaxMana: Int {
        state.maxMana(of: state.hero)
    }

    var petMaxMana: Int {
        state.maxMana(of: state.pet)
    }

    var earnedGold: Int {
        state.earnedGold
    }

    var isBattleOver: Bool {
        state.isBattleOver
    }

    var isEnemyDefeated: Bool {
        state.isEnemyDefeated
    }

    var isPartyDefeated: Bool {
        state.isPartyDefeated
    }

    var outcome: BattleOutcome {
        if isEnemyDefeated { return .victory }
        if isPartyDefeated { return .defeat }
        return .ongoing
    }

    func makeVictorySummary(homestead: PlayerHomesteadState) -> BattleVictorySummary {
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.heroProgression.level
        let heroXP = ExperienceScaling.battleAward(
            playerLevel: configuration.heroProgression.level,
            enemyLevel: enemyLevel
        )
        let petXP = ExperienceScaling.battleAward(
            playerLevel: configuration.petProgression.level,
            enemyLevel: enemyLevel
        )
        let heroAfter = configuration.heroProgression.addingExperience(heroXP)
        let petAfter = configuration.petProgression.addingExperience(petXP)
        let materialRewards = homestead.adjustedMaterialRewards(
            configuration.stageReward?.materialRewards ?? []
        )

        return BattleVictorySummary(
            stageGold: configuration.stageReward?.gold ?? 0,
            battleGold: earnedGold,
            experience: heroXP,
            petExperience: petXP,
            heroName: hero.name,
            petName: pet.name,
            itemNames: configuration.rewardItemNames,
            materialRewards: materialRewards,
            heroProgressionBefore: configuration.heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.petProgression,
            petProgressionAfter: petAfter
        )
    }

    func reset(from configuration: ActiveBattleConfiguration) {
        state = BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max)
        )
        activeFeedbackEvents = []
        feedbackDisplayedAt = [:]
    }

    func removeFeedbackEvent(_ id: Int) {
        activeFeedbackEvents.removeAll { $0.id == id }
        feedbackDisplayedAt.removeValue(forKey: id)
    }

    func pruneExpiredFeedback(at date: Date = .now) {
        let expiredIDs = feedbackDisplayedAt.compactMap { eventID, displayedAt in
            date.timeIntervalSince(displayedAt) >= CombatFeedbackTiming.displayDuration ? eventID : nil
        }
        for eventID in expiredIDs {
            removeFeedbackEvent(eventID)
        }
    }

    @discardableResult
    func advanceOneStep() -> BattleStep {
        let step = state.advanceOneStep()
        let displayedAt = Date.now
        step.events
            .filter { $0.kind != .milestone }
            .forEach {
                activeFeedbackEvents.append($0)
                feedbackDisplayedAt[$0.id] = displayedAt
            }
        return step
    }

    func effectSummaries(for combatant: Combatant) -> [EffectSummary] {
        state.effectSummaries(of: combatant)
    }

    func health(for combatant: Combatant) -> Int {
        state.health(of: combatant)
    }

    func maxHealth(for combatant: Combatant) -> Int {
        state.maxHealth(of: combatant)
    }
}
