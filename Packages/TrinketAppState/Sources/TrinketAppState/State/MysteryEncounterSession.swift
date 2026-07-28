import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

public enum MysteryEncounterPhase: Equatable {
    case reading
    case revealing
    case choosingItem
    case selectingCorruptItem
    case revealingCorruption
    case reward
}

public enum MysteryChoiceOutcome: Equatable {
    case reveal(unlockedCombatantID: String)
    case chooseItem(candidates: [InventoryItem])
    case selectCorruptItem
    case corruptionReveal(ItemCorruptionResult)
    case reward(MysteryEffectApplyResult, journey: JourneyProgressState?)
    case dismiss(journey: JourneyProgressState?)
    case failed
}

@MainActor
@Observable
public final class MysteryEncounterSession: Identifiable {
    // swiftformat:disable:next modifierOrder -- SwiftLint requires isolation before access.
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    /// When set, completion clears a Labyrinth node instead of a journey stage.
    public let labyrinthNodeID: String?
    public let event: MysteryEvent
    public let combatant: Combatant?
    public private(set) var phase: MysteryEncounterPhase = .reading
    public private(set) var unlockedCombatantID: String?
    public private(set) var itemCandidates: [InventoryItem] = []
    public private(set) var corruptibleItems: [InventoryItem] = []
    public private(set) var corruptionResult: ItemCorruptionResult?
    public private(set) var applyResult: MysteryEffectApplyResult?
    public private(set) var isResolvingChoice = false
    public private(set) var persistFailureMessage: String?

    public var showsReveal: Bool {
        phase == .revealing && unlockedCombatantID != nil
    }

    public var showsItemChoice: Bool {
        phase == .choosingItem && !itemCandidates.isEmpty
    }

    public var showsCorruptItemChoice: Bool {
        phase == .selectingCorruptItem && !corruptibleItems.isEmpty
    }

    public var showsCorruptionReveal: Bool {
        phase == .revealingCorruption && corruptionResult != nil
    }

    public var showsReward: Bool {
        phase == .reward && applyResult != nil
    }

    public var isCorruptionAltar: Bool {
        event.id == GameContent.corruptionAltarEventID
            || event.choices.contains { $0.effects.contains(.corruptItem) }
    }

    /// True while the encounter is still waiting for a reading-phase choice.
    public var canResolveChoice: Bool {
        phase == .reading && !isResolvingChoice
    }

    public init(
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
        forcedEventID: String?,
        pickContext: MysteryEventPickContext = .excludingCorruptionAltar,
        pinnedLabyrinthEventID: String? = nil
    ) -> (session: MysteryEncounterSession, resolvedEventID: String)? {
        let event: MysteryEvent
        let sessionStage: Stage
        if let labyrinthNodeID {
            event = GameContent.resolveLabyrinthMysteryEvent(
                nodeID: labyrinthNodeID,
                forcedEventID: forcedEventID,
                pinnedEventID: pinnedLabyrinthEventID,
                context: pickContext
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
                context: pickContext,
                using: &pickRNG
            )
            sessionStage = stage
        } else {
            return nil
        }

        let session = MysteryEncounterSession(
            stage: sessionStage,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
            labyrinthNodeID: labyrinthNodeID
        )
        return (session, event.id)
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

    func presentCorruptItemChoice(items: [InventoryItem]) {
        corruptibleItems = items
        phase = .selectingCorruptItem
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func presentCorruptionReveal(result: ItemCorruptionResult) {
        corruptionResult = result
        phase = .revealingCorruption
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func presentReward(result: MysteryEffectApplyResult) {
        applyResult = result
        phase = .reward
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func returnToReading() {
        phase = .reading
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

    private func noteMysteryCadence(save: inout PlayerSave) {
        if isCorruptionAltar {
            ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
        } else {
            ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        }
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

        if choice.effects.contains(.corruptItem) {
            let targets = ItemCorruption.eligibleTargets(in: save.inventory)
            guard !targets.isEmpty else {
                markResolvedWithoutReveal()
                return .failed
            }
            return .selectCorruptItem
        }

        if choice.effects.contains(.leave) {
            noteMysteryCadence(save: &save)
            let journey = completeProgress(save: &save)
            return .dismiss(journey: journey)
        }

        let applyResult = MysteryEffectApplier.apply(
            choice.effects,
            stageID: stage.id,
            choiceID: choice.id,
            save: &save,
            using: &randomNumberGenerator
        )

        if !applyResult.unlockedCombatantIDs.isEmpty {
            if labyrinthNodeID != nil {
                _ = completeProgress(save: &save)
            }
            noteMysteryCadence(save: &save)
            return .reveal(unlockedCombatantID: applyResult.unlockedCombatantIDs[0])
        }

        if !applyResult.chooseItemCandidates.isEmpty {
            return .chooseItem(candidates: applyResult.chooseItemCandidates)
        }

        noteMysteryCadence(save: &save)
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
        noteMysteryCadence(save: &save)
        let journey = completeProgress(save: &save)
        return .reward(MysteryEffectApplyResult(grantedItems: [item]), journey: journey)
    }

    /// Corrupts the chosen inventory item, records altar encounter, and completes progress.
    func corruptSelectedItem(
        itemID: String,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryChoiceOutcome {
        guard phase == .selectingCorruptItem else { return .failed }
        guard !isResolvingChoice else { return .failed }
        guard corruptibleItems.contains(where: { $0.id == itemID }) else { return .failed }

        markChoiceStarted()
        let apply = ItemCorruptionApplier.corrupt(
            itemID: itemID,
            save: &save,
            using: &randomNumberGenerator
        )
        guard case let .success(result) = apply else {
            markResolvedWithoutReveal()
            return .failed
        }
        noteMysteryCadence(save: &save)
        _ = completeProgress(save: &save)
        return .corruptionReveal(result)
    }

    func applyOutcome(_ outcome: MysteryChoiceOutcome, inventory: PlayerInventoryState? = nil) {
        switch outcome {
        case let .reveal(unlockedCombatantID):
            presentReveal(unlockedCombatantID: unlockedCombatantID)
        case let .chooseItem(candidates):
            presentItemChoice(candidates: candidates)
        case .selectCorruptItem:
            let items = inventory.map(ItemCorruption.eligibleTargets(in:)) ?? []
            presentCorruptItemChoice(items: items)
        case let .corruptionReveal(result):
            presentCorruptionReveal(result: result)
        case let .reward(result, _):
            presentReward(result: result)
        case .dismiss, .failed:
            markResolvedWithoutReveal()
        }
    }
}
