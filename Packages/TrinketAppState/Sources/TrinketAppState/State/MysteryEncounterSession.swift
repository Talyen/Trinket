import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

enum MysteryEncounterPhase: Equatable {
    case reading
    case revealing
    case selectingCorruptItem
    case revealingCorruption
    case reward
}

enum MysteryChoiceOutcome: Equatable {
    case reveal(unlockedCombatantID: String)
    case selectCorruptItem
    case corruptionReveal(ItemCorruptionResult)
    case reward(MysteryEffectApplyResult)
    case dismiss
    case failed
}

typealias MysteryProgressCompletion = (
    MysteryEncounterSession,
    inout PlayerSave,
) -> Void

@MainActor
@Observable
public final class MysteryEncounterSession: Identifiable {
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    public let origin: PlayEncounterOrigin
    public var labyrinthNodeID: String? {
        origin.labyrinthNodeID
    }

    public let event: MysteryEvent
    public let combatant: Combatant?
    private(set) var phase: MysteryEncounterPhase = .reading
    public private(set) var unlockedCombatantID: String?
    public private(set) var corruptibleItems: [InventoryItem] = []
    public private(set) var corruptionResult: ItemCorruptionResult?
    public private(set) var applyResult: MysteryEffectApplyResult?
    public private(set) var isResolvingChoice = false
    public private(set) var persistFailureMessage: String?
    public private(set) var previewMaterialQuantity = 0
    public private(set) var previewHeroExperienceAward = 0
    public private(set) var previewCompanionExperienceAward = 0

    static let choiceUnavailableMessage = "That choice isn't available anymore."

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

    public var canResolveChoice: Bool {
        phase == .reading && !isResolvingChoice
    }

    public init(
        origin: PlayEncounterOrigin,
        event: MysteryEvent,
        combatant: Combatant?,
    ) {
        self.origin = origin
        stage = origin.resolvedStage(
            labyrinthEncounter: event.isRecruit
                ? .recruit(eventID: event.id)
                : .mysteryEvent(eventID: event.id),
        )
        self.event = event
        self.combatant = combatant
    }

    static func resolveEvent(
        origin: PlayEncounterOrigin,
        forcedEventID: String?,
        worldSeed: UInt64,
        pickContext: MysteryEventPickContext = .excludingCorruptionAltar,
        pinnedLabyrinthEventID: String? = nil,
        pinnedJourneyEventID: String? = nil,
    ) -> MysteryEvent {
        switch origin {
        case let .labyrinth(nodeID):
            GameContent.resolveLabyrinthMysteryEvent(
                nodeID: nodeID,
                worldSeed: worldSeed,
                forcedEventID: forcedEventID,
                pinnedEventID: pinnedLabyrinthEventID,
                context: pickContext,
            )
        case let .journey(stage):
            GameContent.resolveJourneyMysteryEvent(
                stage: stage,
                worldSeed: worldSeed,
                forcedEventID: forcedEventID,
                pinnedEventID: pinnedJourneyEventID,
                context: pickContext,
            )
        }
    }

    static func open(
        origin: PlayEncounterOrigin,
        forcedEventID: String?,
        worldSeed: UInt64,
        pickContext: MysteryEventPickContext = .excludingCorruptionAltar,
        pinnedLabyrinthEventID: String? = nil,
        pinnedJourneyEventID: String? = nil,
    ) -> (session: MysteryEncounterSession, resolvedEventID: String) {
        let event = resolveEvent(
            origin: origin,
            forcedEventID: forcedEventID,
            worldSeed: worldSeed,
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID,
        )
        let session = MysteryEncounterSession(
            origin: origin,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
        )
        return (session, event.id)
    }

    func installPreviews(save: PlayerSave) {
        let level = MysteryEffectApplier.resolvedEncounterLevel(
            stage: stage,
            labyrinthNodeID: labyrinthNodeID,
            save: save,
        )
        previewMaterialQuantity = MysteryEffectApplier.materialQuantity(forLevel: level)
        let experiencePercent = labyrinthNodeID.map {
            save.labyrinth.effects(for: $0).experienceEarnedPercent
        } ?? 0
        let roster = save.roster
        previewHeroExperienceAward = CombatRounding.scaled(
            MysteryEffectApplier.experienceAward(
                for: roster.progression(for: roster.activeHero),
                highestLevel: roster.highestHeroLevel,
            ),
            byPercent: experiencePercent,
        )
        previewCompanionExperienceAward = CombatRounding.scaled(
            MysteryEffectApplier.experienceAward(
                for: roster.progression(for: roster.activeCompanion),
                highestLevel: roster.highestCompanionLevel,
            ),
            byPercent: experiencePercent,
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

    func markChoiceUnavailable() {
        markPersistFailed(Self.choiceUnavailableMessage)
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

    func resolveChoice(
        choiceID: String?,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        completeProgress: MysteryProgressCompletion,
    ) -> MysteryChoiceOutcome {
        guard canResolveChoice else { return .failed }
        markChoiceStarted()

        func mysteryRewardBonuses(in save: PlayerSave) -> LabyrinthModifierEffects {
            guard let labyrinthNodeID else { return .zero }
            return save.labyrinth.effects(for: labyrinthNodeID)
        }

        let choice: MysteryChoice? = if let choiceID {
            event.choices.first { $0.id == choiceID }
        } else {
            event.choices.first
        }
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

        let rewardBonuses = mysteryRewardBonuses(in: save)
        let applyResult = MysteryEffectApplier.apply(
            choice.effects,
            stageID: stage.id,
            choiceID: choice.id,
            encounterLevel: MysteryEffectApplier.resolvedEncounterLevel(
                stage: stage,
                labyrinthNodeID: labyrinthNodeID,
                save: save,
            ),
            save: &save,
            using: &randomNumberGenerator,
            goldFoundPercent: rewardBonuses.goldFoundPercent,
            experienceEarnedPercent: rewardBonuses.experienceEarnedPercent,
            materialsFoundPercent: rewardBonuses.materialsFoundPercent,
        )

        if !applyResult.unlockedCombatantIDs.isEmpty {
            completeProgress(self, &save)
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

    func corruptSelectedItem(
        itemID: String,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        completeProgress: MysteryProgressCompletion,
    ) -> MysteryChoiceOutcome {
        guard phase == .selectingCorruptItem else { return .failed }
        guard !isResolvingChoice else { return .failed }
        guard corruptibleItems.contains(where: { $0.id == itemID }) else { return .failed }

        markChoiceStarted()
        let apply = ItemCorruptionApplier.corrupt(
            itemID: itemID,
            save: &save,
            using: &randomNumberGenerator,
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
