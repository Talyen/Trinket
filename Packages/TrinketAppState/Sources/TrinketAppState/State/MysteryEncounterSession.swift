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

@MainActor
@Observable
public final class MysteryEncounterSession: Identifiable {
    nonisolated public var id: String {
        stage.id
    }

    public let stage: Stage
    public let origin: PlayEncounterOrigin
    public let encounter: EncounterIdentity
    public var labyrinthNodeID: String? {
        origin.labyrinthNodeID
    }

    public let event: MysteryEvent
    public let combatant: Combatant?
    private(set) var phase: MysteryEncounterPhase = .reading
    public private(set) var unlockedCombatantID: String?
    public private(set) var corruptibleItems: [InventoryItem] = []
    public private(set) var corruptionResult: ItemCorruptionDetail?
    public private(set) var applyResult: MysteryEffectResult?
    public private(set) var isResolvingChoice = false
    public private(set) var persistFailureMessage: String?
    public private(set) var offers: [MysteryOffer] = []

    public var narrative: String {
        event.narrative(for: offers)
    }

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
        encounter: EncounterIdentity,
        event: MysteryEvent,
        combatant: Combatant?,
    ) {
        self.origin = origin
        self.encounter = encounter
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
        encounter: EncounterIdentity,
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
            encounter: encounter,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
        )
        return (session, event.id)
    }

    var resolutionRequest: MysteryEncounterRequest {
        MysteryEncounterRequest(encounter: encounter, stage: stage, event: event, displayedOffers: offers)
    }

    func installOffers(_ offers: [MysteryOffer]) {
        self.offers = offers
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

    func presentCorruptionReveal(result: ItemCorruptionDetail) {
        corruptionResult = result
        phase = .revealingCorruption
        isResolvingChoice = false
        persistFailureMessage = nil
    }

    func presentReward(result: MysteryEffectResult) {
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
        case let .refreshedOffers(offers):
            installOffers(offers)
            returnToReading()
            markPersistFailed("Your rewards changed. Review the offers and choose again.")
        case .dismiss:
            markResolvedWithoutReveal()
        }
    }
}
