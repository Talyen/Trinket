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
    package let deckCopyID: Int

    public init(id: Int, ability: Ability, owner: BattleParticipant) {
        self.id = id
        self.ability = ability
        self.owner = owner
        deckCopyID = id
    }

    package init(id: Int, ability: Ability, owner: BattleParticipant, deckCopyID: Int) {
        self.id = id
        self.ability = ability
        self.owner = owner
        self.deckCopyID = deckCopyID
    }
}

public struct OpeningHandDraw: Hashable, Sendable {
    public let owner: BattleParticipant
    public let tier: AbilityTier?

    public init(owner: BattleParticipant, tier: AbilityTier? = nil) {
        self.owner = owner
        self.tier = tier
    }
}

public struct CombatDeck: Hashable, Sendable {
    package struct Entry: Hashable, Sendable {
        let ability: Ability
        let copyID: Int?
    }

    private var drawPile: [Entry]
    package private(set) var discarded: [Entry] = []

    public var abilities: [Ability] {
        drawPile.map(\.ability)
    }

    public init(abilities: [Ability] = []) {
        drawPile = abilities.map { Entry(ability: $0, copyID: nil) }
    }

    public var isEmpty: Bool {
        drawPile.isEmpty
    }

    public var count: Int {
        drawPile.count
    }

    public mutating func draw() -> Ability? {
        drawEntry()?.ability
    }

    package mutating func drawEntry() -> Entry? {
        guard !drawPile.isEmpty else { return nil }
        return drawPile.removeFirst()
    }

    package mutating func drawFirstEntry(where predicate: (Ability) -> Bool) -> Entry? {
        guard let index = drawPile.firstIndex(where: { predicate($0.ability) }) else { return nil }
        return drawPile.remove(at: index)
    }

    public mutating func putOnBottom(_ ability: Ability) {
        drawPile.append(Entry(ability: ability, copyID: nil))
    }

    package mutating func putOnBottom(_ card: BattleCard) {
        drawPile.append(Entry(ability: card.ability, copyID: card.deckCopyID))
    }

    package mutating func discard(_ card: BattleCard) {
        discarded.append(Entry(ability: card.ability, copyID: card.deckCopyID))
    }

    package mutating func recycleDiscards() {
        drawPile.append(contentsOf: discarded)
        discarded.removeAll(keepingCapacity: true)
    }

    package mutating func recover(copyID: Int) -> Entry? {
        if let index = discarded.firstIndex(where: { $0.copyID == copyID }) {
            return discarded.remove(at: index)
        }
        guard let index = drawPile.firstIndex(where: { $0.copyID == copyID }) else { return nil }
        return drawPile.remove(at: index)
    }

    public static func defaultAbilities(from loadout: AbilityLoadout) -> [Ability] {
        [loadout.basic, loadout.skill, loadout.ultimate].compactMap(\.self)
    }

    public static func shuffled(
        from loadout: AbilityLoadout,
        rng: inout SeededRandomNumberGenerator,
    ) -> Self {
        var abilities = defaultAbilities(from: loadout)
        // Uniform decks hold identical cards, so skipping the shuffle keeps the RNG stream stable.
        if let firstID = abilities.first?.id, abilities.dropFirst().contains(where: { $0.id != firstID }) {
            abilities.shuffle(using: &rng)
        }
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
        cards.removeAll { card in
            guard predicate(card) else { return false }
            removed.append(card)
            return true
        }
        buffer.removeAll { card in
            guard predicate(card) else { return false }
            removed.append(card)
            return true
        }
        return removed
    }

    @discardableResult
    public mutating func promoteFromBuffer(
        isOwnerAlive: (BattleParticipant) -> Bool,
    ) -> [BattleCard] {
        guard !buffer.isEmpty else { return [] }
        var discarded: [BattleCard] = []
        while !isFull, !buffer.isEmpty {
            let result = promoteNextFromBuffer(isOwnerAlive: isOwnerAlive)
            discarded.append(contentsOf: result.discarded)
            guard result.promoted != nil else { break }
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
        // Consume the prefix once so defeated owners don't cause repeated FIFO shifts.
        for index in buffer.indices {
            let card = buffer[index]
            if isOwnerAlive(card.owner) {
                buffer.removeFirst(index + 1)
                cards.append(card)
                return (card, discarded)
            }
            discarded.append(card)
        }
        buffer.removeAll(keepingCapacity: true)
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
