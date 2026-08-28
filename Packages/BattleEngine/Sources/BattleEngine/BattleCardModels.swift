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
        rng: inout SeededRandomNumberGenerator
    ) -> Self {
        var abilities = loadout.abilities
        abilities.shuffle(using: &rng)
        return Self(abilities: abilities)
    }
}

public struct BattleHand: Hashable, Sendable {
    public static let maxSize = 3

    public private(set) var cards: [BattleCard]

    public init(cards: [BattleCard] = []) {
        self.cards = cards
    }

    public var count: Int {
        cards.count
    }

    public var isEmpty: Bool {
        cards.isEmpty
    }

    public func card(id: Int) -> BattleCard? {
        cards.first { $0.id == id }
    }

    public mutating func remove(id: Int) -> BattleCard? {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return nil }
        return cards.remove(at: index)
    }

    public mutating func append(_ card: BattleCard) {
        cards.append(card)
    }

    public var isFull: Bool {
        cards.count >= Self.maxSize
    }
}

public struct BattleHandBuffer: Hashable, Sendable {
    public private(set) var cards: [BattleCard]

    public init(cards: [BattleCard] = []) {
        self.cards = cards
    }

    public var count: Int {
        cards.count
    }

    public var isEmpty: Bool {
        cards.isEmpty
    }

    public mutating func enqueue(_ card: BattleCard) {
        cards.append(card)
    }

    public mutating func dequeue() -> BattleCard? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    public mutating func remove(id: Int) -> BattleCard? {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return nil }
        return cards.remove(at: index)
    }
}

public enum BattlePlayError: Error, Equatable, Sendable {
    case battleOver
    case notPlayerTurn
    case cardNotInHand
    case ownerDefeated
    case ownerSkipping
}
