import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

enum MysteryEncounterPhase: Equatable {
    case reading
    case revealing
    case choosingItem
    case reward
}

enum MysteryChoiceOutcome: Equatable {
    case reveal(unlockedCombatantID: String)
    case chooseItem(candidates: [InventoryItem])
    case reward(MysteryEffectApplyResult, journey: JourneyProgressState?)
    case dismiss(journey: JourneyProgressState?)
    case failed
}

@MainActor
@Observable
final class MysteryEncounterSession: Identifiable {
    nonisolated var id: String {
        stage.id
    }

    let stage: Stage
    /// When set, completion clears a Labyrinth node instead of a journey stage.
    let labyrinthNodeID: String?
    let event: MysteryEvent
    let combatant: Combatant?
    private(set) var phase: MysteryEncounterPhase = .reading
    private(set) var unlockedCombatantID: String?
    private(set) var itemCandidates: [InventoryItem] = []
    private(set) var applyResult: MysteryEffectApplyResult?
    private(set) var isResolvingChoice = false
    private(set) var persistFailureMessage: String?

    var showsReveal: Bool {
        phase == .revealing && unlockedCombatantID != nil
    }

    var showsItemChoice: Bool {
        phase == .choosingItem && !itemCandidates.isEmpty
    }

    var showsReward: Bool {
        phase == .reward && applyResult != nil
    }

    /// True while the encounter is still waiting for a reading-phase choice.
    var canResolveChoice: Bool {
        phase == .reading && !isResolvingChoice
    }

    init(
        stage: Stage,
        event: MysteryEvent,
        combatant: Combatant?,
        labyrinthNodeID: String? = nil
    ) {
        self.stage = stage
        self.event = event
        self.combatant = combatant
        self.labyrinthNodeID = labyrinthNodeID
    }

    /// Assembles a mystery/recruit session for a journey stage or Labyrinth node.
    static func open(
        stage: Stage? = nil,
        labyrinthNodeID: String? = nil,
        forcedEventID: String?
    ) -> MysteryEncounterSession? {
        let event: MysteryEvent
        let sessionStage: Stage
        if let labyrinthNodeID {
            event = GameContent.resolveLabyrinthMysteryEvent(
                nodeID: labyrinthNodeID,
                forcedEventID: forcedEventID
            )
            sessionStage = GameContent.syntheticLabyrinthStage(
                nodeID: labyrinthNodeID,
                encounter: event.isRecruit
                    ? .recruit(eventID: event.id)
                    : .mysteryEvent(eventID: event.id)
            )
        } else if let stage {
            let authoredEvent = forcedEventID.flatMap {
                GameContent.mysteryEvent(matching: $0) ?? GameContent.recruitEvent(matching: $0)
            }
                ?? stage.mysteryEvent
            var pickRNG = SystemRandomNumberGenerator()
            event = GameContent.resolveMysteryEncounterEvent(
                authored: authoredEvent,
                using: &pickRNG
            )
            sessionStage = stage
        } else {
            return nil
        }

        return MysteryEncounterSession(
            stage: sessionStage,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
            labyrinthNodeID: labyrinthNodeID
        )
    }
}

extension MysteryEncounterSession {
    func markChoiceStarted() {
        isResolvingChoice = true
        persistFailureMessage = nil
    }

    func presentReveal(unlockedCombatantID: String) {
        self.unlockedCombatantID = unlockedCombatantID
        phase = .revealing
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func presentItemChoice(candidates: [InventoryItem]) {
        itemCandidates = candidates
        phase = .choosingItem
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func presentReward(result: MysteryEffectApplyResult) {
        applyResult = result
        phase = .reward
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func markResolvedWithoutReveal() {
        isResolvingChoice = false
    }

    func markPersistFailed(_ message: String) {
        isResolvingChoice = false
        persistFailureMessage = message
    }

    func clearPersistFailure() {
        persistFailureMessage = nil
    }

    /// Completes the active mystery's stage or Labyrinth node inside an open save mutation.
    @discardableResult
    func completeProgress(save: inout PlayerSave) -> JourneyProgressState? {
        StageCompletion.completeEncounter(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            in: GameContent.chapters,
            save: &save
        )
    }

    /// Applies the chosen effects and optionally completes progress in one mutation.
    func resolveChoice(
        choiceID: String?,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryChoiceOutcome {
        guard canResolveChoice else { return .failed }
        markChoiceStarted()

        let choice = event.choices.first { $0.id == choiceID } ?? event.choices.first
        guard let choice else {
            markResolvedWithoutReveal()
            return .failed
        }

        let applyResult = MysteryEffectApplier.apply(
            choice.effects,
            stageID: stage.id,
            choiceID: choice.id,
            save: &save,
            using: &randomNumberGenerator
        )

        if !applyResult.unlockedCombatantIDs.isEmpty {
            // Journey recruits delay completion for the unlock screen; authored
            // reopen safety auto-completes if already unlocked. Labyrinth mystery
            // events are re-rolled from the unlocked roster, so complete the node
            // with the unlock to prevent kill/relaunch double-recruits.
            if labyrinthNodeID != nil {
                _ = completeProgress(save: &save)
            }
            return .reveal(unlockedCombatantID: applyResult.unlockedCombatantIDs[0])
        }

        // Choose-item presents candidates next; grant + complete on selection.
        if !applyResult.chooseItemCandidates.isEmpty {
            return .chooseItem(candidates: applyResult.chooseItemCandidates)
        }

        let journey = completeProgress(save: &save)
        if !applyResult.isEmpty {
            return .reward(applyResult, journey: journey)
        }
        return .dismiss(journey: journey)
    }

    /// Grants the chosen mystery item and completes progress in one mutation.
    func selectItem(itemID: String, save: inout PlayerSave) -> MysteryChoiceOutcome {
        guard showsItemChoice else { return .failed }
        guard !isResolvingChoice else { return .failed }
        guard let item = itemCandidates.first(where: { $0.id == itemID }) else {
            return .failed
        }

        markChoiceStarted()
        MysteryEffectApplier.grantChosenItem(item, save: &save)
        let journey = completeProgress(save: &save)
        return .reward(MysteryEffectApplyResult(grantedItems: [item]), journey: journey)
    }

    func applyOutcome(_ outcome: MysteryChoiceOutcome) {
        switch outcome {
        case let .reveal(unlockedCombatantID):
            presentReveal(unlockedCombatantID: unlockedCombatantID)
        case let .chooseItem(candidates):
            presentItemChoice(candidates: candidates)
        case let .reward(result, _):
            presentReward(result: result)
        case .dismiss, .failed:
            markResolvedWithoutReveal()
        }
    }
}
