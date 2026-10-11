import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketPersistence

@MainActor
@Observable
public final class MysteryEncounterSession: Identifiable {
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
    @ObservationIgnored private var hasCollectedReward = false

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
        unlockedCombatantID != nil
    }

    public var showsCorruptItemChoice: Bool {
        !corruptibleItems.isEmpty
    }

    public var showsCorruptionReveal: Bool {
        corruptionResult != nil
    }

    public var showsReward: Bool {
        applyResult != nil
    }

    public var isCorruptionAltar: Bool {
        event.id == GameContent.corruptionAltarEventID
            || event.choices.contains { $0.effects.contains(.corruptItem) }
    }

    public var canResolveChoice: Bool {
        guard case .reading = presentation else { return false }
        return !isResolvingChoice
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

    func claimRewardCollectionSound() -> Bool {
        guard showsReward, !hasCollectedReward else { return false }
        hasCollectedReward = true
        return true
    }

    var resolutionRequest: MysteryEncounterRequest {
        MysteryEncounterRequest(encounter: encounter, eventID: event.id, displayedOffers: offers)
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
            let items = inventory.map { ItemCorruption.eligibleTargets(in: $0.items) } ?? []
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
