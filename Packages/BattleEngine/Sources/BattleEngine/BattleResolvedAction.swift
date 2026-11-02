import TrinketCore

public struct BattleResolvedAction: Equatable, Sendable {
    public let id: Int
    public let startedAfterEventID: Int
    public let actorID: String
    public let abilityID: String
    public let cardID: Int?
    public let isAttack: Bool
    public internal(set) var eventIDs: [Int]
    public internal(set) var damage: [BattleResolvedDamage]

    public init(
        id: Int,
        actorID: String,
        abilityID: String,
        cardID: Int?,
        isAttack: Bool,
        eventIDs: [Int],
        damage: [BattleResolvedDamage] = [],
        startedAfterEventID: Int = 0,
    ) {
        self.id = id
        self.startedAfterEventID = startedAfterEventID
        self.actorID = actorID
        self.abilityID = abilityID
        self.cardID = cardID
        self.isAttack = isAttack
        self.eventIDs = eventIDs
        self.damage = damage
    }
}

public struct BattleResolvedDamage: Equatable, Sendable {
    public let targetID: String
    public let keyword: Keyword
    public let impact: CombatOutcome.DamageImpact
    public let isCritical: Bool

    public init(
        targetID: String,
        keyword: Keyword,
        impact: CombatOutcome.DamageImpact,
        isCritical: Bool,
    ) {
        self.targetID = targetID
        self.keyword = keyword
        self.impact = impact
        self.isCritical = isCritical
    }
}
