import Foundation
import TrinketContent
import TrinketCore

public enum BattlePhase: Equatable, Sendable {
    case playerTurn
    case ended
}

public struct BattleCard: Identifiable, Hashable, Sendable {
    public let id: Int
    public let ability: Ability
    public let owner: BattleParticipant

    public init(id: Int, ability: Ability, owner: BattleParticipant) {
        self.id = id
        self.ability = ability
        self.owner = owner
    }
}

public struct OpeningHandDraw: Hashable, Sendable {
    public let owner: BattleParticipant
    public let tier: AbilityTier

    public init(owner: BattleParticipant, tier: AbilityTier) {
        self.owner = owner
        self.tier = tier
    }
}

public struct CombatDeck: Hashable, Sendable {
    public private(set) var abilities: [Ability]

    public init(abilities: [Ability] = []) {
        self.abilities = abilities
    }

    public var isEmpty: Bool {
        abilities.isEmpty
    }

    public var count: Int {
        abilities.count
    }

    public mutating func draw() -> Ability? {
        guard !abilities.isEmpty else { return nil }
        return abilities.removeFirst()
    }

    public mutating func drawFirst(where predicate: (Ability) -> Bool) -> Ability? {
        guard let index = abilities.firstIndex(where: predicate) else { return nil }
        return abilities.remove(at: index)
    }

    public mutating func putOnBottom(_ ability: Ability) {
        abilities.append(ability)
    }

    public static func shuffled(
        from loadout: AbilityLoadout,
        rng: inout SeededRandomNumberGenerator,
    ) -> Self {
        var abilities = loadout.abilities
        abilities.shuffle(using: &rng)
        return Self(abilities: abilities)
    }
}

public struct BattleHand: Hashable, Sendable {
    public static let maxSize = 3

    public private(set) var cards: [BattleCard]
    public private(set) var buffer: [BattleCard]

    public init(cards: [BattleCard] = [], buffer: [BattleCard] = []) {
        self.cards = cards
        self.buffer = buffer
    }

    public var count: Int {
        cards.count
    }

    public var bufferCount: Int {
        buffer.count
    }

    public var totalCount: Int {
        cards.count + buffer.count
    }

    public var isEmpty: Bool {
        cards.isEmpty && buffer.isEmpty
    }

    public var visibleIsEmpty: Bool {
        cards.isEmpty
    }

    public func card(id: Int) -> BattleCard? {
        cards.first { $0.id == id }
    }

    public mutating func remove(id: Int) -> BattleCard? {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return nil }
        return cards.remove(at: index)
    }

    mutating func removeFromAnyLocation(id: Int) -> BattleCard? {
        if let card = remove(id: id) {
            return card
        }
        guard let index = buffer.firstIndex(where: { $0.id == id }) else { return nil }
        return buffer.remove(at: index)
    }

    public mutating func append(_ card: BattleCard) {
        if isFull || !buffer.isEmpty {
            buffer.append(card)
        } else {
            cards.append(card)
        }
    }

    @discardableResult
    public mutating func removeAll(where predicate: (BattleCard) -> Bool) -> [BattleCard] {
        var removed: [BattleCard] = []
        var survivingCards: [BattleCard] = []
        for card in cards {
            if predicate(card) {
                removed.append(card)
            } else {
                survivingCards.append(card)
            }
        }
        cards = survivingCards

        var survivingBuffer: [BattleCard] = []
        for card in buffer {
            if predicate(card) {
                removed.append(card)
            } else {
                survivingBuffer.append(card)
            }
        }
        buffer = survivingBuffer
        return removed
    }

    @discardableResult
    public mutating func promoteFromBuffer(
        isOwnerAlive: (BattleParticipant) -> Bool,
    ) -> [BattleCard] {
        guard !buffer.isEmpty else { return [] }
        var discarded: [BattleCard] = []
        while !isFull, !buffer.isEmpty {
            let card = buffer.removeFirst()
            if isOwnerAlive(card.owner) {
                cards.append(card)
            } else {
                discarded.append(card)
            }
        }
        return discarded
    }

    @discardableResult
    public mutating func promoteNextFromBuffer(
        isOwnerAlive: (BattleParticipant) -> Bool,
    ) -> (promoted: BattleCard?, discarded: [BattleCard]) {
        guard !isFull, !buffer.isEmpty else {
            return (nil, [])
        }
        var discarded: [BattleCard] = []
        while !buffer.isEmpty {
            let card = buffer.removeFirst()
            if isOwnerAlive(card.owner) {
                cards.append(card)
                return (card, discarded)
            }
            discarded.append(card)
            if isFull {
                break
            }
        }
        return (nil, discarded)
    }

    public var isFull: Bool {
        cards.count >= Self.maxSize
    }
}

public enum BattlePlayError: Error, Equatable, Sendable {
    case battleOver
    case notPlayerTurn
    case cardNotInHand
    case ownerDefeated
    case ownerSkipping
    case insufficientHealth
}

// MARK: - Play recording

final class BattleCardPlayRecording {
    private let recording: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void
    private var pendingEvents: [ActionEvent] = []
    private var cards: [(card: BattleCard, hasAction: Bool)] = []
    private var actions: [BattleResolvedAction] = []

    init(_ recording: @escaping (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void) {
        self.recording = recording
    }

    static func detached(
        _ recording: ((BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void)?,
    ) -> ((BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void)? {
        recording.map { callback in
            { checkpoint, state, events in
                var snapshot = state
                snapshot.cardPlayRecording = nil
                callback(checkpoint, snapshot, events)
            }
        }
    }

    func append(_ event: ActionEvent) {
        pendingEvents.append(event)
        if !actions.isEmpty {
            actions[actions.count - 1].eventIDs.append(event.id)
        }
    }

    func beginAction(id: Int, actorID: String, abilityID: String, isAttack: Bool, afterEventID: Int) {
        let cardID = cards.last.flatMap { $0.hasAction ? nil : $0.card.id }
        if !cards.isEmpty {
            cards[cards.count - 1].hasAction = true
        }
        actions.append(BattleResolvedAction(
            id: id, actorID: actorID, abilityID: abilityID, cardID: cardID,
            isAttack: isAttack, eventIDs: [], startedAfterEventID: afterEventID,
        ))
    }

    func endAction(state: BattleState) {
        guard let action = actions.popLast() else { return }
        var snapshot = state
        snapshot.cardPlayRecording = nil
        recording(.actionResolved(action), snapshot, [])
    }

    func recordDamage(_ damage: BattleResolvedDamage) {
        guard !actions.isEmpty else { return }
        actions[actions.count - 1].damage.append(damage)
    }

    func record(_ checkpoint: BattleTransitionCheckpoint, state: BattleState) {
        switch checkpoint {
        case let .cardWillPlay(card): cards.append((card, false))
        case .cardActions: _ = cards.popLast()
        default: break
        }
        var snapshot = state
        snapshot.cardPlayRecording = nil
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        recording(checkpoint, snapshot, events)
    }
}

extension BattleState {
    mutating func recordCardPlay(_ checkpoint: BattleTransitionCheckpoint) {
        cardPlayRecording?.record(checkpoint, state: self)
    }
}
