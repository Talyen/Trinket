import Foundation
import TrinketCore

public struct BoonCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let keywords: [Keyword]

    public init(id: String, name: String, keywords: [Keyword]) {
        precondition(keywords.count == 2)
        precondition(Set(keywords).count == 2)
        self.id = id
        self.name = name
        self.keywords = keywords
    }
}

public enum BoonEffect: Hashable, Sendable {
    case controlDoublesPartyBlock(Keyword)
    case blockedDamageReturned(Keyword)
    case damageGrantsPartyBlock(Keyword)
    case damageIgnoresBlockAndDodgeWhileBlocked(Keyword)
    case storedBlockedDamage(Keyword)
    case consumeBlockForBonusDamage(Keyword)
    case damagePurgesAll(Keyword)
    case purgeDealsDamage(keyword: Keyword, amount: Int)
    case mirroredDamage(source: Keyword, result: Keyword, multiplier: Double)
    case criticalDamageMultiplier(keyword: Keyword, targetStatus: Keyword, multiplier: Double)
    case criticalGoldAndDraw(gold: Int, cards: Int)
    case goldGuaranteesCritical(keyword: Keyword, threshold: Int)
    case manaSpentDealsDamage(Keyword)
    case damageRestoresMana(Keyword)
    case statusDamageMultiplier(status: Keyword, damage: Keyword, multiplier: Double)
    case damageDetonates(damage: Keyword, effect: Keyword, requiresCritical: Bool)
    case preserveBleedWhileFrozen
    case dodgeDrawsAndPlays(Keyword)
    case criticalGrantsDodge(Keyword)
    case cleanseRestoresHealth(Int)
    case overhealCleanses
    case damageDrawsCard(damage: Keyword, card: Keyword)
    case cardPrimesRepeat(trigger: Keyword, repeated: Keyword)
    case criticalDoublesBleedDuration(Keyword)
    case damageGrantsBlock(Keyword)
    case freezeDamageStealsBlock
}

public struct BoonDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: BoonCategory
    public let description: String
    public let effect: BoonEffect

    public init(
        id: String,
        name: String,
        category: BoonCategory,
        description: String,
        effect: BoonEffect,
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.effect = effect
    }
}
