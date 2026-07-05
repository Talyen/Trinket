import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

enum BattleAutoTickAction: Equatable {
    case completeWithEarnedGold(Int)
}

@MainActor
@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration? {
        didSet {
            if let activeBattle {
                resetRun(from: activeBattle)
            } else {
                clearRunState()
            }
        }
    }

    var isPaused = false
    var isShowingVictory = false
    var isShowingDefeat = false
    var victorySummary: BattleVictorySummary?
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantDetailContext?
    private(set) var state: BattleState?
    var activeFeedbackEvents: [ActionEvent] = []
    private var feedbackDisplayedAt: [Int: Date] = [:]
    private var overlayPauseDepth = 0
    private var pauseStateBeforeFirstOverlay: Bool?
    var onBattleStateChange: ((String?) -> Void)?
    var onBattleEnded: (() -> Void)?

    var outcome: BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleOutcomeResolver.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    func endBattle() {
        activeBattle = nil
        isPaused = false
        clearOutcomePresentation()
        preview = nil
        overlayCombatantDetail = nil
        overlayPauseDepth = 0
        pauseStateBeforeFirstOverlay = nil
        onBattleStateChange?(nil)
        onBattleEnded?()
    }

    func clearOutcomePresentation() {
        isShowingVictory = false
        isShowingDefeat = false
        victorySummary = nil
    }

    func canAutoAdvanceTick() -> Bool {
        guard let state, !state.isBattleOver, !isPaused else { return false }
        return !isShowingVictory && !isShowingDefeat
    }

    @discardableResult
    func handlePeriodicTick(
        at date: Date,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> BattleAutoTickAction? {
        pruneExpiredFeedback(at: date)
        return advanceAutoTick(journey: journey, homestead: homestead)
    }

    @discardableResult
    func advanceAutoTick(
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> BattleAutoTickAction? {
        guard canAutoAdvanceTick(),
              let configuration = activeBattle else { return nil }

        advanceOneStep()

        switch outcome {
        case .victory:
            if Self.stageRewardsAlreadyClaimed(stageID: configuration.stageID, journey: journey) {
                return .completeWithEarnedGold(state?.earnedGold ?? 0)
            }
            guard let battleState = state else { return nil }
            victorySummary = BattleVictorySummary.make(
                configuration: configuration,
                state: battleState,
                homestead: homestead
            )
            isShowingVictory = true
            return nil
        case .defeat:
            isShowingDefeat = true
            return nil
        case .none, .tickLimit:
            return nil
        }
    }

    func setMusicPreview(for stage: Stage?) {
        guard activeBattle == nil,
              let stage,
              let enemyID = stage.encounter.battleEnemyID
        else {
            preview = nil
            return
        }

        preview = BattleMusicPreview(stageID: stage.id, enemyID: enemyID)
    }

    @discardableResult
    func startBattle(
        stage: Stage,
        hero: Combatant,
        pet: Combatant,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore
    ) -> StageMapMessage? {
        guard activeBattle == nil else { return nil }

        guard let encounter = StageEncounterResolver.resolve(for: stage) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        preview = nil
        activeBattle = makeActiveConfiguration(
            stageID: stage.id,
            hero: hero,
            pet: pet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            roster: roster,
            inventory: inventory,
            stageReward: stage.rewards,
            rewardItemNames: rewardItemNames(for: stage.rewards)
        )
        onBattleStateChange?(stage.id)
        return nil
    }

    func restartBattle(using roster: PlayerRosterStore, inventory: PlayerInventoryStore) {
        guard let activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.id })
            ?? roster.activePet

        self.activeBattle = makeActiveConfiguration(
            from: activeBattle,
            hero: hero,
            pet: pet,
            roster: roster,
            inventory: inventory
        )
    }

    static func stageRewardsAlreadyClaimed(
        stageID: String?,
        journey: JourneyProgressState
    ) -> Bool {
        guard let stageID,
              let stage = GameContent.stage(id: stageID) else { return false }
        return journey.hasClaimedRewards(for: stage)
    }

    func pauseForOverlay() {
        if overlayPauseDepth == 0 {
            pauseStateBeforeFirstOverlay = isPaused
        }
        overlayPauseDepth += 1
        isPaused = true
    }

    func restorePauseAfterOverlay() {
        guard overlayPauseDepth > 0 else { return }
        overlayPauseDepth -= 1
        guard activeBattle != nil else {
            overlayPauseDepth = 0
            pauseStateBeforeFirstOverlay = nil
            return
        }
        if overlayPauseDepth == 0 {
            isPaused = pauseStateBeforeFirstOverlay ?? false
            pauseStateBeforeFirstOverlay = nil
        }
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        if activeBattle != nil {
            pauseForOverlay()
        }
        overlayCombatantDetail = CombatantDetailContext(snapshot: detail)
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
    func advanceOneStep() -> BattleStep? {
        guard var state else { return nil }
        let step = state.advanceOneStep()
        self.state = state
        let displayedAt = Date.now
        step.events
            .filter { $0.kind != .milestone }
            .forEach {
                activeFeedbackEvents.append($0)
                feedbackDisplayedAt[$0.id] = displayedAt
            }
        return step
    }

    private func makeActiveConfiguration(
        stageID: String?,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        stageReward: StageReward?,
        rewardItemNames: [String],
        rngSeed: UInt64 = UInt64.random(in: UInt64.min ... UInt64.max)
    ) -> ActiveBattleConfiguration {
        ActiveBattleConfiguration.make(
            stageID: stageID,
            rngSeed: rngSeed,
            hero: hero,
            pet: pet,
            roster: roster,
            inventory: inventory,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            rewardItemNames: rewardItemNames
        )
    }

    private func makeActiveConfiguration(
        from template: ActiveBattleConfiguration,
        hero: Combatant,
        pet: Combatant,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        rngSeed: UInt64 = UInt64.random(in: UInt64.min ... UInt64.max)
    ) -> ActiveBattleConfiguration {
        makeActiveConfiguration(
            stageID: template.stageID,
            hero: hero,
            pet: pet,
            enemy: template.enemy,
            enemyEncounterLevel: template.enemyEncounterLevel,
            roster: roster,
            inventory: inventory,
            stageReward: template.stageReward,
            rewardItemNames: template.rewardItemNames,
            rngSeed: rngSeed
        )
    }

    private static func rewardItemNames(for stageReward: StageReward) -> [String] {
        stageReward.itemTemplateIDs.compactMap { templateID in
            GameContent.itemTemplate(matching: templateID)?.displayName
        }
    }

    private func resetRun(from configuration: ActiveBattleConfiguration) {
        state = BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed
        )
        activeFeedbackEvents = []
        feedbackDisplayedAt = [:]
        clearOutcomePresentation()
    }

    private func clearRunState() {
        state = nil
        activeFeedbackEvents = []
        feedbackDisplayedAt = [:]
        clearOutcomePresentation()
    }
}
