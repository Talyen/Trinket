import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

public enum MysteryEncounterPhase: Equatable {
    case reading
    case revealing
    case selectingCorruptItem
    case revealingCorruption
    case reward
}

public enum MysteryChoiceOutcome: Equatable {
    case reveal(unlockedCombatantID: String)
    case selectCorruptItem
    case corruptionReveal(ItemCorruptionResult)
    case reward(MysteryEffectApplyResult)
    case dismiss
    case failed
}

typealias MysteryProgressCompletion = (
    MysteryEncounterSession,
    inout PlayerSave
) -> Void

@MainActor
@Observable
public final class MysteryEncounterSession: Identifiable {
    // swiftformat:disable:next modifierOrder -- SwiftLint requires isolation before access.
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    public let origin: PlayEncounterOrigin
    /// When set, completion clears a Labyrinth node instead of a journey stage.
    public var labyrinthNodeID: String? {
        origin.labyrinthNodeID
    }

    public let event: MysteryEvent
    public let combatant: Combatant?
    public private(set) var phase: MysteryEncounterPhase = .reading
    public private(set) var unlockedCombatantID: String?
    public private(set) var corruptibleItems: [InventoryItem] = []
    public private(set) var corruptionResult: ItemCorruptionResult?
    public private(set) var applyResult: MysteryEffectApplyResult?
    public private(set) var isResolvingChoice = false
    public private(set) var persistFailureMessage: String?

    public var showsReveal: Bool {
        phase == .revealing && unlockedCombatantID != nil
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
        origin: PlayEncounterOrigin,
        event: MysteryEvent,
        combatant: Combatant?
    ) {
        self.origin = origin
        switch origin {
        case let .journey(stage):
            self.stage = stage
        case let .labyrinth(nodeID):
            stage = GameContent.syntheticLabyrinthStage(
                nodeID: nodeID,
                encounter: event.isRecruit
                    ? .recruit(eventID: event.id)
                    : .mysteryEvent(eventID: event.id)
            )
        }
        self.event = event
        self.combatant = combatant
    }

    /// Assembles a mystery/recruit session for a journey stage or Labyrinth node.
    static func open(
        origin: PlayEncounterOrigin,
        forcedEventID: String?,
        pickContext: MysteryEventPickContext = .excludingCorruptionAltar,
        pinnedLabyrinthEventID: String? = nil,
        pinnedJourneyEventID: String? = nil
    ) -> (session: MysteryEncounterSession, resolvedEventID: String) {
        let event = switch origin {
        case let .labyrinth(nodeID):
            GameContent.resolveLabyrinthMysteryEvent(
                nodeID: nodeID,
                forcedEventID: forcedEventID,
                pinnedEventID: pinnedLabyrinthEventID,
                context: pickContext
            )
        case let .journey(stage):
            GameContent.resolveJourneyMysteryEvent(
                stage: stage,
                forcedEventID: forcedEventID,
                pinnedEventID: pinnedJourneyEventID,
                context: pickContext
            )
        }

        let session = MysteryEncounterSession(
            origin: origin,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event)
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
        using randomNumberGenerator: inout some RandomNumberGenerator,
        completeProgress: MysteryProgressCompletion
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
            completeProgress(self, &save)
            return .dismiss
        }

        let applyResult = MysteryEffectApplier.apply(
            choice.effects,
            stageID: stage.id,
            choiceID: choice.id,
            save: &save,
            using: &randomNumberGenerator
        )

        if !applyResult.unlockedCombatantIDs.isEmpty {
            if case .labyrinth = origin {
                completeProgress(self, &save)
            }
            noteMysteryCadence(save: &save)
            return .reveal(unlockedCombatantID: applyResult.unlockedCombatantIDs[0])
        }

        noteMysteryCadence(save: &save)
        completeProgress(self, &save)
        if !applyResult.isEmpty {
            return .reward(applyResult)
        }
        return .dismiss
    }

    /// Corrupts the chosen inventory item, records altar encounter, and completes progress.
    func corruptSelectedItem(
        itemID: String,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        completeProgress: MysteryProgressCompletion
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
        completeProgress(self, &save)
        return .corruptionReveal(result)
    }

    func applyOutcome(_ outcome: MysteryChoiceOutcome, inventory: PlayerInventoryState? = nil) {
        switch outcome {
        case let .reveal(unlockedCombatantID):
            presentReveal(unlockedCombatantID: unlockedCombatantID)
        case .selectCorruptItem:
            let items = inventory.map(ItemCorruption.eligibleTargets(in:)) ?? []
            presentCorruptItemChoice(items: items)
        case let .corruptionReveal(result):
            presentCorruptionReveal(result: result)
        case let .reward(result):
            presentReward(result: result)
        case .dismiss, .failed:
            markResolvedWithoutReveal()
        }
    }
}
