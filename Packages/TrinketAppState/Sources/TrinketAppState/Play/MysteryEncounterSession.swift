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
public final class MysteryEncounterSession: Identifiable, EncounterSession {
    public nonisolated var id: String {
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
    public private(set) var offers: [MysteryOffer] = []

    /// Each screen owns its payload; leaving it releases the previous result.
    private enum Presentation {
        case reading
        case reveal(combatantID: String)
        case corruptItemChoice([InventoryItem])
        case corruptionReveal(ItemCorruptionDetail)
        case reward(MysteryEffectResult)
    }

    private enum ChoiceAttempt {
        case ready
        case resolving
        case failed(String)
    }

    private var presentation: Presentation = .reading
    private var choiceAttempt: ChoiceAttempt = .ready

    var phase: MysteryEncounterPhase {
        switch presentation {
        case .reading: .reading
        case .reveal: .revealing
        case .corruptItemChoice: .selectingCorruptItem
        case .corruptionReveal: .revealingCorruption
        case .reward: .reward
        }
    }

    public var unlockedCombatantID: String? {
        guard case let .reveal(id) = presentation else { return nil }
        return id
    }

    public var corruptibleItems: [InventoryItem] {
        guard case let .corruptItemChoice(items) = presentation else { return [] }
        return items
    }

    public var corruptionResult: ItemCorruptionDetail? {
        guard case let .corruptionReveal(result) = presentation else { return nil }
        return result
    }

    public var applyResult: MysteryEffectResult? {
        guard case let .reward(result) = presentation else { return nil }
        return result
    }

    public var isResolvingChoice: Bool {
        if case .resolving = choiceAttempt {
            return true
        }
        return false
    }

    public var persistFailureMessage: String? {
        guard case let .failed(message) = choiceAttempt else { return nil }
        return message
    }

    public var narrative: String {
        event.narrative(for: offers)
    }

    static let choiceUnavailableMessage = "That choice isn't available anymore."

    public var showsReveal: Bool {
        phase == .revealing
    }

    public var showsCorruptItemChoice: Bool {
        phase == .selectingCorruptItem && !corruptibleItems.isEmpty
    }

    public var showsCorruptionReveal: Bool {
        phase == .revealingCorruption
    }

    public var showsReward: Bool {
        phase == .reward
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
        case let .labyrinth(nodeID), let .voyage(_, nodeID):
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
    ) -> MysteryEncounterSession {
        let event = resolveEvent(
            origin: origin,
            forcedEventID: forcedEventID,
            worldSeed: worldSeed,
            pickContext: pickContext,
            pinnedLabyrinthEventID: pinnedLabyrinthEventID,
            pinnedJourneyEventID: pinnedJourneyEventID,
        )
        return MysteryEncounterSession(
            origin: origin,
            encounter: encounter,
            event: event,
            combatant: GameContent.combatant(forMysteryEvent: event),
        )
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
        choiceAttempt = .resolving
    }

    private func present(_ presentation: Presentation) {
        self.presentation = presentation
        choiceAttempt = .ready
    }

    func returnToReading() {
        present(.reading)
    }

    func markPersistFailed(_ message: String) {
        choiceAttempt = .failed(message)
    }

    func markChoiceUnavailable() {
        markPersistFailed(Self.choiceUnavailableMessage)
    }

    func clearPersistFailure() {
        if case .failed = choiceAttempt {
            choiceAttempt = .ready
        }
    }

    func applyOutcome(_ outcome: MysteryChoiceOutcome, inventory: PlayerInventoryState? = nil) {
        switch outcome {
        case let .reveal(unlockedCombatantID):
            present(.reveal(combatantID: unlockedCombatantID))
        case .selectCorruptItem:
            let items = inventory.map(ItemCorruption.eligibleTargets(in:)) ?? []
            present(.corruptItemChoice(items))
        case let .corruptionReveal(result):
            present(.corruptionReveal(result))
        case let .reward(result):
            present(.reward(result))
        case let .refreshedOffers(offers):
            installOffers(offers)
            returnToReading()
            markPersistFailed("Your rewards changed. Review the offers and choose again.")
        case .dismiss:
            present(.reading)
        }
    }
}
