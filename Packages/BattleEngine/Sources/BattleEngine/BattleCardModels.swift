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
    /// Always `.hero` or `.pet` for cards in the player's hand.
    public let owner: BattleParticipant

    public init(id: Int, ability: Ability, owner: BattleParticipant) {
        self.id = id
        self.ability = ability
        self.owner = owner
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

    public mutating func putOnBottom(_ ability: Ability) {
        abilities.append(ability)
    }

    public static func shuffled(
        from loadout: AbilityLoadout,
        rng: inout SeededRandomNumberGenerator
    ) -> CombatDeck {
        var abilities = loadout.abilities
        abilities.shuffle(using: &rng)
        return CombatDeck(abilities: abilities)
    }
}

public struct BattleHand: Hashable, Sendable {
    public static let softCap = 8

    public private(set) var cards: [BattleCard]

    public init(cards: [BattleCard] = []) {
        self.cards = cards
    }

    public var count: Int {
        cards.count
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

    public var isAtSoftCap: Bool {
        cards.count >= Self.softCap
    }
}

public enum BattlePlayError: Error, Equatable, Sendable {
    case battleOver
    case notPlayerTurn
    case cardNotInHand
    case ownerDefeated
    case ownerSkipping
}
