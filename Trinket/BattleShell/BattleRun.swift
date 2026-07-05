import BattleEngine
import TrinketContent
import TrinketCore
import TrinketPersistence

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
        state = Self.makeState(from: configuration)
    }

    var outcome: BattleOutcome {
        switch BattleOutcomeResolver.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        ) {
        case .victory: return .victory
        case .defeat: return .defeat
        case .tickLimit, .none: return .ongoing
        }
    }

    func makeVictorySummary(homestead: PlayerHomesteadState) -> BattleVictorySummary {
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.heroProgression.level
        let heroCatchUp = ExperienceScaling.catchUpMultiplier(
            for: configuration.heroProgression.level,
            highestLevel: configuration.highestHeroLevel
        )
        let petCatchUp = ExperienceScaling.catchUpMultiplier(
            for: configuration.petProgression.level,
            highestLevel: configuration.highestPetLevel
        )
        let baseHeroXP = ExperienceScaling.battleAward(
            playerLevel: configuration.heroProgression.level,
            enemyLevel: enemyLevel
        )
        let basePetXP = ExperienceScaling.battleAward(
            playerLevel: configuration.petProgression.level,
            enemyLevel: enemyLevel
        )
        let heroXP = baseHeroXP > 0 ? max(1, Int((Double(baseHeroXP) * heroCatchUp).rounded())) : 0
        let petXP = basePetXP > 0 ? max(1, Int((Double(basePetXP) * petCatchUp).rounded())) : 0
        let heroAfter = configuration.heroProgression.addingExperience(heroXP)
        let petAfter = configuration.petProgression.addingExperience(petXP)
        let materialRewards = homestead.adjustedMaterialRewards(
            configuration.stageReward?.materialRewards ?? []
        )

        return BattleVictorySummary(
            stageGold: configuration.stageReward?.gold ?? 0,
            battleGold: state.earnedGold,
            experience: heroXP,
            petExperience: petXP,
            heroName: state.hero.name,
            petName: state.pet.name,
            itemNames: configuration.rewardItemNames,
            materialRewards: materialRewards,
            heroProgressionBefore: configuration.heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.petProgression,
            petProgressionAfter: petAfter
        )
    }

    func reset(from configuration: ActiveBattleConfiguration) {
        state = Self.makeState(from: configuration)
        activeFeedbackEvents = []
        feedbackDisplayedAt = [:]
    }

    private static func makeState(from configuration: ActiveBattleConfiguration) -> BattleState {
        BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed
        )
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
}
