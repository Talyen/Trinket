import Foundation

public enum EffectTarget: Hashable, Sendable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case companion
    case lowestHealthAlly
    case defeatedAlly
    case eachAlly
}

public enum DamageScaling: Hashable, Sendable {
    case actorBlockFraction(divisor: Int, minimum: Int)
}

public struct DamageComponent: Hashable, Sendable {
    public let amount: Int
    public let keyword: Keyword
    public let target: EffectTarget
    public let bonusAmount: Int
    public let condition: DamageCondition?
    public let scaling: DamageScaling?

    public init(
        _ amount: Int,
        keyword: Keyword = .physical,
        target: EffectTarget = .abilityTarget,
        bonusAmount: Int = 0,
        condition: DamageCondition? = nil,
        scaling: DamageScaling? = nil,
    ) {
        self.amount = amount
        self.keyword = keyword
        self.target = target
        self.bonusAmount = bonusAmount
        self.condition = condition
        self.scaling = scaling
    }

    /// Component-level rule: any Burn/Freeze damage component. The effect-level
    /// twin (`Effect.isManaEmpowerableBurnOrFreezeDamage`) covers only `.burn`
    /// and Burn/Freeze `recurringDamage`; both share `manaEmpowermentBonus`.
    public var isManaEmpowerableBurnOrFreezeDamage: Bool {
        keyword == .burn || keyword == .freeze
    }

    public func withManaEmpowerment(_ amount: Int = Effect.manaEmpowermentBonus) -> Self {
        guard isManaEmpowerableBurnOrFreezeDamage else { return self }
        return Self(
            self.amount + amount,
            keyword: keyword,
            target: target,
            bonusAmount: bonusAmount > 0 ? bonusAmount + amount : 0,
            condition: condition,
            scaling: scaling,
        )
    }

    public var hasPotentialDamage: Bool {
        scaling != nil || amount + bonusAmount > 0
    }
}

public struct TargetedEffect: Hashable, Sendable {
    public let effect: Effect
    public let target: EffectTarget
    public let condition: DamageCondition?

    public init(_ effect: Effect, target: EffectTarget? = nil, condition: DamageCondition? = nil) {
        self.effect = effect
        self.target = target ?? Effect.defaultTarget(for: effect)
        self.condition = condition
    }
}

public enum Effect: Hashable, Sendable {
    case burn(Int)
    case poison(Int)
    case bleed(Int)
    case controlMeter(Keyword, Int, Int)
    case shield(Keyword, Int)
    case instantHeal(Keyword, Int)
    case resourceGain(Keyword, Int)
    case drawCards(Int)
    case drawAndPlayCards(Int)
    case cleanse(Keyword?)
    case cleanseRandom
    case purge(Keyword?)
    case purgeRandom
    case halveShield(Keyword)
    case deathsDoor
    case thorns(Int)
    case thornsFromBlockFraction(divisor: Int, minimum: Int)
    case marked(Int, Int)
    case criticalChanceBonus(Double, Int)
    case restoreManaOnHit(Int, Int)
    case damageKeywordOverride(Keyword, Int, Int)
    case nextHolyStrike
    case nextStrikeDouble
    case nextBurnBonus(Int)
    case evadeNextHit
    case convertManaToBlock
    case shieldFromMana
    case shieldFromHalfMana
    case shieldFromGold(goldPerBlock: Int)
    case maximumManaBonus(Int)
    case nextStrikeCritical
    case nextStrikeLeech
    case nextStrikeDamageKeywordOverride(Keyword)
    case partyDamageBonus(Int)
    case freezeNextAttacker
    case onHitDamage(Keyword, Int)
    case cleanseHealPerDebuff(Int)
    case panacea(baseHeal: Int, healPerDebuff: Int)
    case multiplyControlMeter(Keyword, Int)
    case multiplyDoT(Keyword, Int)
    case detonateDoT(Keyword, Int)
    case recurringDamage(Keyword, Int, Int)
    case blessedAegis(block: Int, holyDamage: Int)
    case avatar(holyDamage: Int, blockPerTurn: Int, turns: Int)
    case revive(Int)
    case damageReductionPercent(Double, Int)
    case damageReductionFlat(Int, Int)
    case healingReductionPercent(Double, Int)
    case hemorrhage(Int)

    public static let bleedDoTTurnCount = 1
    public static let abilityLeechPercent = 0.50
    public static let standardMarkedDuration = 3
    public static let standardMarkedBonus = 2
    /// Mana empowerment bonus shared by `DamageComponent.withManaEmpowerment`,
    /// `Effect.withManaEmpowerment`, and the "Spend 3 Mana" line in
    /// `Keyword.mana.rulesText` (cost itself lives in
    /// `BattleEngine.BattleTurnEngine`). Update together.
    public static let manaEmpowermentBonus = 1

    public static func decayingDoT(keyword: Keyword, potency: Int) -> Self {
        switch keyword {
        case .burn: .burn(potency)
        default: .poison(potency)
        }
    }

    public var keyword: Keyword {
        switch self {
        case .burn: .burn
        case .poison: .poison
        case .bleed: .bleed
        case let .controlMeter(k, _, _): k
        case let .shield(k, _): k
        case let .instantHeal(k, _): k
        case let .resourceGain(k, _): k
        case .drawCards, .drawAndPlayCards: .physical
        case let .cleanse(k?): k
        case .cleanse(nil), .cleanseRandom, .cleanseHealPerDebuff, .panacea: .cleanse
        case let .purge(k?): k
        case .purge(nil), .purgeRandom: .purge
        case let .halveShield(k): k
        case .deathsDoor: .deathsDoor
        case .thorns, .thornsFromBlockFraction: .thorns
        case .marked: .physical
        case .criticalChanceBonus: .physical
        case .restoreManaOnHit: .mana
        case let .damageKeywordOverride(k, _, _): k
        case .nextHolyStrike: .holy
        case .nextStrikeDouble: .physical
        case .nextBurnBonus: .burn
        case .evadeNextHit: .dodge
        case .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: .block
        case .maximumManaBonus: .mana
        case .nextStrikeCritical: .physical
        case .nextStrikeLeech: .leech
        case let .nextStrikeDamageKeywordOverride(k): k
        case .partyDamageBonus: .physical
        case .freezeNextAttacker: .freeze
        case let .onHitDamage(k, _): k
        case let .multiplyControlMeter(k, _): k
        case let .multiplyDoT(k, _): k
        case let .detonateDoT(k, _): k
        case let .recurringDamage(k, _, _): k
        case .avatar, .blessedAegis: .holy
        case .revive: .health
        case .damageReductionPercent: .physical
        case .damageReductionFlat: .physical
        case .healingReductionPercent: .physical
        case .hemorrhage: .bleed
        }
    }

    public var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): p
        case let .thorns(p): p
        case let .onHitDamage(_, p): p
        case let .recurringDamage(_, p, _): p
        case let .avatar(holyDamage, _, _): holyDamage
        case let .hemorrhage(p): p
        default: nil
        }
    }

    public var isManaEmpowerableBurnOrFreezeDamage: Bool {
        switch self {
        case .burn:
            true
        case let .recurringDamage(keyword, _, _):
            keyword == .burn || keyword == .freeze
        default:
            false
        }
    }

    public func withManaEmpowerment(_ amount: Int = manaEmpowermentBonus) -> Self {
        switch self {
        case let .burn(potency):
            .burn(potency + amount)
        case let .recurringDamage(keyword, potency, turns)
            where keyword == .burn || keyword == .freeze:
            .recurringDamage(keyword, potency + amount, turns)
        default:
            self
        }
    }

    /// Zero covers two lifecycles by design: instant effects (resolved immediately,
    /// never stored) and indefinite effects (stored until removed or consumed).
    /// Disambiguate with `isInstant`, `advancesEachTurn`, and the removability
    /// flags on `EffectKind`.
    public var durationTurns: Int {
        switch self {
        case .bleed: Self.bleedDoTTurnCount
        case let .marked(_, d): d
        case let .criticalChanceBonus(_, d): d
        case let .restoreManaOnHit(_, d): d
        case let .damageKeywordOverride(_, _, d): d
        case let .recurringDamage(_, _, d): d
        case let .avatar(_, _, d): d
        case let .damageReductionPercent(_, d), let .damageReductionFlat(_, d), let .healingReductionPercent(_, d): d
        case .burn, .poison, .instantHeal, .resourceGain, .drawCards, .drawAndPlayCards, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveShield, .controlMeter, .deathsDoor,
             .shield, .thorns, .thornsFromBlockFraction, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold, .maximumManaBonus,
             .nextStrikeCritical, .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .partyDamageBonus,
             .freezeNextAttacker, .onHitDamage,
             .multiplyControlMeter, .multiplyDoT, .detonateDoT,
             .revive,
             .cleanseHealPerDebuff, .panacea, .blessedAegis, .hemorrhage:
            0
        }
    }

    public static func poisonDecayAmount(for potency: Int) -> Int {
        max(1, potency * 25 / 100)
    }

    public func potencyAfterTurn(burnDecaySlowPercent: Double = 0, poisonDecaySlowPercent: Double = 0) -> Int {
        switch self {
        case let .burn(potency):
            let normalNext = potency / 2
            let loss = potency - normalNext
            let adjustedLoss = CombatRounding.scaled(loss, multiplier: 1 - clamped01(burnDecaySlowPercent))
            return potency - adjustedLoss
        case let .poison(potency):
            let loss = Self.poisonDecayAmount(for: potency)
            let adjustedLoss = CombatRounding.scaled(loss, multiplier: 1 - clamped01(poisonDecaySlowPercent))
            return max(0, potency - adjustedLoss)
        default:
            return 0
        }
    }

    /// Clamps a slow-percent to [0, 1]; decay math needs the bound twice.
    private func clamped01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    public var summary: String {
        EffectPresentation.applyPhrase(for: self)
    }

    public static func defaultTarget(for effect: Self) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .controlMeter, .halveShield, .purge, .purgeRandom, .marked,
             .multiplyControlMeter, .multiplyDoT, .detonateDoT, .recurringDamage, .hemorrhage,
             .damageReductionPercent, .damageReductionFlat, .healingReductionPercent:
            .abilityTarget
        case .instantHeal:
            .lowestHealthAlly
        case .revive:
            .defeatedAlly
        case .shield, .resourceGain, .drawCards, .drawAndPlayCards, .cleanse, .cleanseRandom,
             .cleanseHealPerDebuff, .panacea,
             .deathsDoor, .thorns, .thornsFromBlockFraction, .criticalChanceBonus, .restoreManaOnHit,
             .damageKeywordOverride, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold, .maximumManaBonus,
             .nextStrikeCritical, .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .partyDamageBonus,
             .freezeNextAttacker, .onHitDamage,
             .avatar, .blessedAegis:
            .actor
        }
    }
}
