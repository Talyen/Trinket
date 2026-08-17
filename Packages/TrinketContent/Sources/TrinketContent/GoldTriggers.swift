import Foundation
import TrinketCore

/// The `gold` trigger family of `CombatTraitTriggers`.
public struct GoldTriggers: Equatable, Hashable, Sendable {
    public var gainGoldBonusHealSelf: Int = 0
    public var defeatEnemyGoldFlat: Int = 0
    public var leechGoldFlat: Int = 0
    public var goldPerTurn: Int = 0
    public var victoryGoldFlat: Int = 0
    public var victoryGoldCoin: Bool = false
    public var criticalGoldFlat: Int = 0
    public var criticalActionGoldFlat: Int = 0
    public var startBattleBonusGold: Int = 0
    public var onGainGoldDrawCardOncePerTurn: Bool = false
    public var onGainGoldHealParty: Int = 0
    public var goldEveryNTurnsInterval: Int = 0
    public var goldEveryNTurnsAmount: Int = 0
    public var onEnemyAbilityDrawAndGoldDraw: Int = 0
    public var onEnemyAbilityGold: Int = 0
    public var criticalVsStunnedEnemyGold: Int = 0
    public var critOnDefeatGold: Int = 0
    public var critOnDefeatGoldAndDrawDraw: Int = 0
    public var partyGoldGainedPercent: Double = 0
    public var goldAbsorbsDamage: Bool = false
    public var goldDoubledWhileFullHealth: Bool = false
    public var onGainGoldDoubleStatusEffectsNextCard: Bool = false

    public init(
        gainGoldBonusHealSelf: Int = 0,
        defeatEnemyGoldFlat: Int = 0,
        leechGoldFlat: Int = 0,
        goldPerTurn: Int = 0,
        victoryGoldFlat: Int = 0,
        victoryGoldCoin: Bool = false,
        criticalGoldFlat: Int = 0,
        criticalActionGoldFlat: Int = 0,
        startBattleBonusGold: Int = 0,
        onGainGoldDrawCardOncePerTurn: Bool = false,
        onGainGoldHealParty: Int = 0,
        goldEveryNTurnsInterval: Int = 0,
        goldEveryNTurnsAmount: Int = 0,
        onEnemyAbilityDrawAndGoldDraw: Int = 0,
        onEnemyAbilityGold: Int = 0,
        criticalVsStunnedEnemyGold: Int = 0,
        critOnDefeatGold: Int = 0,
        critOnDefeatGoldAndDrawDraw: Int = 0,
        partyGoldGainedPercent: Double = 0,
        goldAbsorbsDamage: Bool = false,
        goldDoubledWhileFullHealth: Bool = false,
        onGainGoldDoubleStatusEffectsNextCard: Bool = false
    ) {
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.defeatEnemyGoldFlat = defeatEnemyGoldFlat
        self.leechGoldFlat = leechGoldFlat
        self.goldPerTurn = goldPerTurn
        self.victoryGoldFlat = victoryGoldFlat
        self.victoryGoldCoin = victoryGoldCoin
        self.criticalGoldFlat = criticalGoldFlat
        self.criticalActionGoldFlat = criticalActionGoldFlat
        self.startBattleBonusGold = startBattleBonusGold
        self.onGainGoldDrawCardOncePerTurn = onGainGoldDrawCardOncePerTurn
        self.onGainGoldHealParty = onGainGoldHealParty
        self.goldEveryNTurnsInterval = goldEveryNTurnsInterval
        self.goldEveryNTurnsAmount = goldEveryNTurnsAmount
        self.onEnemyAbilityDrawAndGoldDraw = onEnemyAbilityDrawAndGoldDraw
        self.onEnemyAbilityGold = onEnemyAbilityGold
        self.criticalVsStunnedEnemyGold = criticalVsStunnedEnemyGold
        self.critOnDefeatGold = critOnDefeatGold
        self.critOnDefeatGoldAndDrawDraw = critOnDefeatGoldAndDrawDraw
        self.partyGoldGainedPercent = partyGoldGainedPercent
        self.goldAbsorbsDamage = goldAbsorbsDamage
        self.goldDoubledWhileFullHealth = goldDoubledWhileFullHealth
        self.onGainGoldDoubleStatusEffectsNextCard = onGainGoldDoubleStatusEffectsNextCard
    }
}

extension GoldTriggers {
    mutating func merge(_ other: Self) {
        gainGoldBonusHealSelf += other.gainGoldBonusHealSelf
        defeatEnemyGoldFlat += other.defeatEnemyGoldFlat
        leechGoldFlat += other.leechGoldFlat
        goldPerTurn += other.goldPerTurn
        victoryGoldFlat += other.victoryGoldFlat
        victoryGoldCoin = victoryGoldCoin || other.victoryGoldCoin
        criticalGoldFlat += other.criticalGoldFlat
        criticalActionGoldFlat += other.criticalActionGoldFlat
        startBattleBonusGold += other.startBattleBonusGold
        onGainGoldDrawCardOncePerTurn = onGainGoldDrawCardOncePerTurn || other.onGainGoldDrawCardOncePerTurn
        onGainGoldHealParty += other.onGainGoldHealParty
        goldEveryNTurnsInterval = max(goldEveryNTurnsInterval, other.goldEveryNTurnsInterval)
        goldEveryNTurnsAmount += other.goldEveryNTurnsAmount
        onEnemyAbilityDrawAndGoldDraw += other.onEnemyAbilityDrawAndGoldDraw
        onEnemyAbilityGold += other.onEnemyAbilityGold
        criticalVsStunnedEnemyGold += other.criticalVsStunnedEnemyGold
        critOnDefeatGold += other.critOnDefeatGold
        critOnDefeatGoldAndDrawDraw += other.critOnDefeatGoldAndDrawDraw
        partyGoldGainedPercent += other.partyGoldGainedPercent
        goldAbsorbsDamage = goldAbsorbsDamage || other.goldAbsorbsDamage
        goldDoubledWhileFullHealth = goldDoubledWhileFullHealth || other.goldDoubledWhileFullHealth
        onGainGoldDoubleStatusEffectsNextCard = onGainGoldDoubleStatusEffectsNextCard || other.onGainGoldDoubleStatusEffectsNextCard
    }
}

extension GoldTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix: DefaultingTriggerDecoder?) throws {
        try self.init(
            gainGoldBonusHealSelf: values.decode(Int.self, "gainGoldBonusHealSelf", default: 0),
            defeatEnemyGoldFlat: values.decode(
                Int.self,
                "defeatEnemyGoldFlat",
                default: legacyAffix?.decode(Int.self, "defeatEnemyGoldFlat", default: 0) ?? 0
            ),
            leechGoldFlat: values.decode(
                Int.self,
                "leechGoldFlat",
                default: legacyAffix?.decode(Int.self, "leechGoldFlat", default: 0) ?? 0
            ),
            goldPerTurn: values.decode(Int.self, "goldPerTurn", default: 0),
            victoryGoldFlat: values.decode(Int.self, "victoryGoldFlat", default: 0),
            victoryGoldCoin: values.decode(Bool.self, "victoryGoldCoin", default: false),
            criticalGoldFlat: values.decode(
                Int.self,
                "criticalGoldFlat",
                default: legacyAffix?.decode(Int.self, "criticalGoldFlat", default: 0) ?? 0
            ),
            criticalActionGoldFlat: values.decode(Int.self, "criticalActionGoldFlat", default: 0),
            startBattleBonusGold: values.decode(Int.self, "startBattleBonusGold", default: 0),
            onGainGoldDrawCardOncePerTurn: values.decode(Bool.self, "onGainGoldDrawCardOncePerTurn", default: false),
            onGainGoldHealParty: values.decode(Int.self, "onGainGoldHealParty", default: 0),
            goldEveryNTurnsInterval: values.decode(Int.self, "goldEveryNTurnsInterval", default: 0),
            goldEveryNTurnsAmount: values.decode(Int.self, "goldEveryNTurnsAmount", default: 0),
            onEnemyAbilityDrawAndGoldDraw: values.decode(Int.self, "onEnemyAbilityDrawAndGoldDraw", default: 0),
            onEnemyAbilityGold: values.decode(Int.self, "onEnemyAbilityGold", default: 0),
            criticalVsStunnedEnemyGold: values.decode(Int.self, "criticalVsStunnedEnemyGold", default: 0),
            critOnDefeatGold: values.decode(Int.self, "critOnDefeatGold", default: 0),
            critOnDefeatGoldAndDrawDraw: values.decode(Int.self, "critOnDefeatGoldAndDrawDraw", default: 0),
            partyGoldGainedPercent: values.decode(Double.self, "partyGoldGainedPercent", default: 0),
            goldAbsorbsDamage: values.decode(Bool.self, "goldAbsorbsDamage", default: false),
            goldDoubledWhileFullHealth: values.decode(Bool.self, "goldDoubledWhileFullHealth", default: false),
            onGainGoldDoubleStatusEffectsNextCard: values.decode(Bool.self, "onGainGoldDoubleStatusEffectsNextCard", default: false)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(gainGoldBonusHealSelf, "gainGoldBonusHealSelf", default: 0)
        try container.encodeNonDefault(defeatEnemyGoldFlat, "defeatEnemyGoldFlat", default: 0)
        try container.encodeNonDefault(leechGoldFlat, "leechGoldFlat", default: 0)
        try container.encodeNonDefault(goldPerTurn, "goldPerTurn", default: 0)
        try container.encodeNonDefault(victoryGoldFlat, "victoryGoldFlat", default: 0)
        try container.encodeNonDefault(victoryGoldCoin, "victoryGoldCoin", default: false)
        try container.encodeNonDefault(criticalGoldFlat, "criticalGoldFlat", default: 0)
        try container.encodeNonDefault(criticalActionGoldFlat, "criticalActionGoldFlat", default: 0)
        try container.encodeNonDefault(startBattleBonusGold, "startBattleBonusGold", default: 0)
        try container.encodeNonDefault(onGainGoldDrawCardOncePerTurn, "onGainGoldDrawCardOncePerTurn", default: false)
        try container.encodeNonDefault(onGainGoldHealParty, "onGainGoldHealParty", default: 0)
        try container.encodeNonDefault(goldEveryNTurnsInterval, "goldEveryNTurnsInterval", default: 0)
        try container.encodeNonDefault(goldEveryNTurnsAmount, "goldEveryNTurnsAmount", default: 0)
        try container.encodeNonDefault(onEnemyAbilityDrawAndGoldDraw, "onEnemyAbilityDrawAndGoldDraw", default: 0)
        try container.encodeNonDefault(onEnemyAbilityGold, "onEnemyAbilityGold", default: 0)
        try container.encodeNonDefault(criticalVsStunnedEnemyGold, "criticalVsStunnedEnemyGold", default: 0)
        try container.encodeNonDefault(critOnDefeatGold, "critOnDefeatGold", default: 0)
        try container.encodeNonDefault(critOnDefeatGoldAndDrawDraw, "critOnDefeatGoldAndDrawDraw", default: 0)
        try container.encodeNonDefault(partyGoldGainedPercent, "partyGoldGainedPercent", default: 0)
        try container.encodeNonDefault(goldAbsorbsDamage, "goldAbsorbsDamage", default: false)
        try container.encodeNonDefault(goldDoubledWhileFullHealth, "goldDoubledWhileFullHealth", default: false)
        try container.encodeNonDefault(onGainGoldDoubleStatusEffectsNextCard, "onGainGoldDoubleStatusEffectsNextCard", default: false)
    }
}
