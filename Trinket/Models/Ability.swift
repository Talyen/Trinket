import SwiftUI

struct StatusApplication: Hashable {
    let keyword: Keyword
    let durationTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(keyword.rawValue) \(tickDamage) for \(durationTicks) ticks"
    }
}

struct ActiveStatus: Identifiable, Equatable, Hashable {
    let id: Int
    let keyword: Keyword
    var remainingTicks: Int
    let tickDamage: Int

    var summary: String {
        "\(remainingTicks) ticks remaining, \(tickDamage) damage each tick"
    }
}

struct StatusSummary: Identifiable, Equatable, Hashable {
    let keyword: Keyword
    let stackCount: Int
    let totalTickDamage: Int

    var id: Keyword {
        keyword
    }

    var text: String {
        "\(keyword.rawValue): \(totalTickDamage) damage next tick, \(stackCount) \(stackCount == 1 ? "stack" : "stacks")."
    }
}

enum EffectTarget: Hashable {
    case abilityTarget
    case actor
    case enemy
    case hero
    case pet
}

struct TargetedEffect: Hashable {
    let effect: Effect
    let target: EffectTarget

    init(_ effect: Effect, target: EffectTarget? = nil) {
        self.effect = effect
        self.target = target ?? Effect.defaultTarget(for: effect)
    }
}

enum Effect: Hashable {
    case burn(Int)
    case poison(Int)
    case bleed(Int)
    case prevention(Keyword, Int)
    case preventionBuildup(Keyword, Int, Int)
    case shield(Keyword, Int, Int)
    case mitigation(Keyword, Double, Int)
    case instantHeal(Keyword, Int)
    case leech(Keyword, Double, Int)
    case resourceGain(Keyword, Int)
    case cleanse(Keyword?, Int)
    case dealDamage(Keyword, Int)
    case cleanseRandom
    case halveMitigation(Keyword)
    case dodge(Keyword, Int)

    static let bleedDoTTickCount = 3
    static let standardLeechPercent = 0.10
    static let standardLeechDuration = 6
    static let standardLeechBuff = Effect.leech(.leech, standardLeechPercent, standardLeechDuration)

    var keyword: Keyword {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case let .prevention(k, _): return k
        case let .preventionBuildup(k, _, _): return k
        case let .shield(k, _, _): return k
        case let .mitigation(k, _, _): return k
        case let .instantHeal(k, _): return k
        case let .leech(k, _, _): return k
        case let .resourceGain(k, _): return k
        case let .cleanse(k?, _): return k
        case .cleanse(nil, _), .cleanseRandom: return .health
        case let .dealDamage(k, _): return k
        case let .halveMitigation(k): return k
        case .dodge: return .dodge
        }
    }

    var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): return p
        case let .dealDamage(_, amount): return amount
        default: return nil
        }
    }

    var durationTicks: Int {
        switch self {
        case .bleed: return Self.bleedDoTTickCount
        case let .prevention(_, d): return d
        case let .shield(_, _, d): return d
        case let .mitigation(_, _, d): return d
        case let .leech(_, _, d): return d
        case let .cleanse(_, d): return d
        case let .dodge(_, d): return d
        case .burn, .poison, .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation, .preventionBuildup: return 0
        }
    }

    func potencyAfterTick() -> Int {
        switch self {
        case let .burn(potency):
            return potency / 2
        case let .poison(potency):
            let decrease = max(1, potency * 25 / 100)
            return potency - decrease
        default:
            return 0
        }
    }

    var summary: String {
        switch self {
        case let .burn(amount):
            return statusPhrase(for: .burn, amount: amount)
        case let .poison(amount):
            return statusPhrase(for: .poison, amount: amount)
        case let .bleed(amount):
            return statusPhrase(for: .bleed, amount: amount)
        case let .prevention(keyword, _):
            return "applies \(keyword.statusAlias ?? keyword.rawValue)"
        case let .preventionBuildup(keyword, _, _):
            return "applies \(keyword.rawValue) Build-up"
        case .shield(.block, _, _):
            return "gain Block"
        case .mitigation(.armor, _, _):
            return "gain Armor"
        case let .instantHeal(.health, amount):
            return "restore \(amount) Health"
        case .leech:
            return "gain Leech"
        case let .resourceGain(.gold, amount):
            return "gain \(amount) Gold"
        case let .cleanse(keyword?, _):
            return "cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case .cleanse(nil, _):
            return "cleanse all debuffs"
        case .cleanseRandom:
            return "cleanse a random debuff"
        case let .dealDamage(keyword, amount):
            return "deal \(amount) \(keyword.rawValue) damage"
        case .halveMitigation(.armor):
            return "reduce enemy Armor by half"
        case .dodge:
            return "gain Dodge"
        default:
            return keyword.rawValue
        }
    }

    private func statusPhrase(for keyword: Keyword, amount _: Int) -> String {
        let alias = keyword.statusAlias ?? keyword.rawValue
        return "applies \(alias)"
    }

    static func defaultTarget(for effect: Effect) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup, .dealDamage, .halveMitigation:
            return .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .cleanse, .cleanseRandom, .dodge:
            return .actor
        }
    }

    static func effect(from status: StatusApplication) -> Effect {
        switch status.keyword {
        case .burn: return .burn(status.tickDamage)
        case .poison: return .poison(status.tickDamage)
        case .bleed: return .bleed(status.tickDamage)
        default: return .poison(status.tickDamage)
        }
    }
}

struct ActiveEffect: Identifiable, Hashable {
    let id: Int
    var effect: Effect
    var remainingTicks: Int
    var sourceActorID: String?

    init(id: Int, effect: Effect, remainingTicks: Int, sourceActorID: String? = nil) {
        self.id = id
        self.effect = effect
        self.remainingTicks = remainingTicks
        self.sourceActorID = sourceActorID
    }

    var keyword: Keyword {
        effect.keyword
    }

    var summary: String {
        switch effect {
        case .burn, .poison:
            return effect.keyword.statusAlias ?? effect.keyword.rawValue
        case let .bleed(potency):
            return "\(effect.keyword.statusAlias ?? effect.keyword.rawValue): \(potency) damage"
        case let .prevention(keyword, _):
            return keyword.statusAlias ?? keyword.rawValue
        case let .preventionBuildup(keyword, amount, threshold):
            return "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        case let .shield(k, b, _):
            return "\(k.rawValue): \(b) buffer"
        case let .mitigation(k, p, _):
            return "\(k.rawValue): \(Int(p * 100))%"
        case .leech:
            return "Leech"
        case .cleanse:
            return "Cleanse"
        case .dodge:
            return "Dodge"
        case .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
            return ""
        }
    }
}

struct EffectSummary: Identifiable, Equatable, Hashable {
    let keyword: Keyword
    let text: String

    var id: Keyword {
        keyword
    }
}

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: AbilityTier
    let directDamage: Int
    let damageKeyword: Keyword
    let description: String
    let statusApplication: StatusApplication?
    let targetedEffects: [TargetedEffect]

    var effects: [Effect] {
        targetedEffects.map(\.effect)
    }

    init(
        id: String,
        name: String,
        tier: AbilityTier,
        directDamage: Int,
        damageKeyword: Keyword = .physical,
        description: String,
        statusApplication: StatusApplication? = nil,
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.directDamage = directDamage
        self.damageKeyword = damageKeyword
        self.description = description
        self.statusApplication = statusApplication
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
    }

    // MARK: - Abilities

    static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let antivenomPotion = Ability(
        id: "antivenom-potion", name: "Antivenom Potion", tier: .skill, directDamage: 0,
        description: "Cleanse Poisoned and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(.poison, 0)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let anvil = Ability(
        id: "anvil", name: "Anvil", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.",
        targetedEffects: []
    )
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic, directDamage: 0,
        description: "Restore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.",
        targetedEffects: []
    )
    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.\nGain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 4, 6))]
    )
    static let block = Ability(
        id: "block", name: "Block", tier: .basic, directDamage: 0,
        description: "Gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 2, 6))]
    )
    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill, directDamage: 0,
        description: "Lose 2 Health and gain Leech.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.physical, 2), target: .actor),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate, directDamage: 0,
        description: "Deal 2 Nature, 2 Bleed, and 2 Poison damage and gain Leech.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.nature, 2)),
            TargetedEffect(.dealDamage(.bleed, 2)),
            TargetedEffect(.bleed(2)),
            TargetedEffect(.dealDamage(.poison, 2)),
            TargetedEffect(.poison(2)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage and gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let bread = Ability(
        id: "bread", name: "Bread", tier: .basic, directDamage: 0,
        description: "Restore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.25, 6))
        ]
    )
    static let burningBlade = Ability(
        id: "burning-blade", name: "Burning Blade", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let cauterize = Ability(
        id: "cauterize", name: "Cauterize", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage, applies Burning, and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill, directDamage: 0,
        description: "Cleanse all debuffs and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(nil, 0)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill, directDamage: 3, damageKeyword: .freeze,
        description: "Deal 3 Freeze damage.",
        targetedEffects: []
    )
    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(6))]
    )
    static let concussiveShot = Ability(
        id: "concussive-shot", name: "Concussive Shot", tier: .ultimate, directDamage: 6, damageKeyword: .stun,
        description: "Deal 6 Stun damage.",
        targetedEffects: []
    )
    static let crystalBulwark = Ability(
        id: "crystal-bulwark", name: "Crystal Bulwark", tier: .ultimate, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 5, 6)),
            TargetedEffect(.mitigation(.armor, 0.35, 6))
        ]
    )
    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill, directDamage: 0,
        description: "Restore 3 Health and gain Leech.",
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and cleanse all debuffs.",
        targetedEffects: [TargetedEffect(.cleanse(nil, 0), target: .abilityTarget)]
    )
    static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic, directDamage: 1, damageKeyword: .bleed,
        description: "Deal 1 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(1))]
    )
    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate, directDamage: 6,
        description: "Lose 3 Health, deal 6 Physical damage, and gain 3 Gold.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.physical, 3), target: .actor),
            TargetedEffect(.resourceGain(.gold, 3))
        ]
    )
    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic, directDamage: 1, damageKeyword: .burn,
        description: "Deal 1 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let fireball = Ability(
        id: "fireball", name: "Fireball", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let frostbolt = Ability(
        id: "frostbolt", name: "Frostbolt", tier: .skill, directDamage: 3, damageKeyword: .freeze,
        description: "Deal 3 Freeze damage.",
        targetedEffects: []
    )
    static let gamblersShot = Ability(
        id: "gamblers-shot", name: "Gambler's Shot", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage and gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate, directDamage: 3, damageKeyword: .freeze,
        description: "Gain Block and deal 3 Freeze damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6))
        ]
    )
    static let gold = Ability(
        id: "gold", name: "Gold", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate, directDamage: 0,
        description: "Gain Armor and gain 4 Gold.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.gold, 4))
        ]
    )
    static let graspingVines = Ability(
        id: "grasping-vines", name: "Grasping Vines", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.\nRestore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let haste = Ability(
        id: "haste", name: "Haste", tier: .skill, directDamage: 0,
        description: "Gain Armor.",
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.25, 6))]
    )
    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill, directDamage: 0,
        description: "Restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let healthPotion = Ability(
        id: "health-potion", name: "Health Potion", tier: .skill, directDamage: 0,
        description: "Restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate, directDamage: 6, damageKeyword: .bleed,
        description: "Deal 6 Bleed damage, applies Bleeding, and gain Leech.",
        targetedEffects: [
            TargetedEffect(.bleed(6)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let holyRadiance = Ability(
        id: "holy-radiance", name: "Holy Radiance", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic, directDamage: 1, damageKeyword: .freeze,
        description: "Deal 1 Freeze damage.",
        targetedEffects: []
    )
    static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic, directDamage: 1, damageKeyword: .burn,
        description: "Deal 1 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let lightningArrow = Ability(
        id: "lightning-arrow", name: "Lightning Arrow", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.",
        targetedEffects: []
    )
    static let lightningBolt = Ability(
        id: "lightning-bolt", name: "Lightning Bolt", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.",
        targetedEffects: []
    )
    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate, directDamage: 0,
        description: "Gain 3 Gold and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaCrystals = Ability(
        id: "mana-crystals", name: "Mana Crystals", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill, directDamage: 0,
        description: "Gain 2 Gold and gain Block.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.shield(.block, 2, 6))
        ]
    )
    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill, directDamage: 0,
        description: "Gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 3, 6))]
    )
    static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(6))]
    )
    static let mixedPotion = Ability(
        id: "mixed-potion", name: "Mixed Potion", tier: .skill, directDamage: 0,
        description: "Restore 2 Health and cleanse a random debuff.",
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate, directDamage: 3, damageKeyword: .burn,
        description: "Gain Block and deal 3 Burn damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.burn(3))
        ]
    )
    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate, directDamage: 3,
        description: "Deal 3 Physical damage and gain Leech.",
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )
    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate, directDamage: 0,
        description: "Cleanse all debuffs and restore 4 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(nil, 0)),
            TargetedEffect(.instantHeal(.health, 4))
        ]
    )
    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage, applies Burning, and restore 3 Health.",
        targetedEffects: [
            TargetedEffect(.burn(6)),
            TargetedEffect(.instantHeal(.health, 3))
        ]
    )
    static let pixie = Ability(
        id: "pixie", name: "Pixie", tier: .ultimate, directDamage: 0,
        description: "Restore 4 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 4))]
    )
    static let placeholderCard = Ability(
        id: "placeholder-card", name: "Placeholder Card", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage."
    )
    static let plateMail = Ability(
        id: "plate-mail", name: "Plate Mail", tier: .ultimate, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.mitigation(.armor, 0.30, 6))
        ]
    )
    static let poisonDagger = Ability(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill, directDamage: 0,
        description: "Restore 2 Health and cleanse a random debuff.",
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic, directDamage: 1, damageKeyword: .freeze,
        description: "Deal 1 Freeze damage.",
        targetedEffects: []
    )
    static let roulette = Ability(
        id: "roulette", name: "Roulette", tier: .skill, directDamage: 3,
        description: "Deal 3 Physical damage and gain 3 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let sanctifiedPlate = Ability(
        id: "sanctified-plate", name: "Sanctified Plate", tier: .ultimate, directDamage: 0, damageKeyword: .holy,
        description: "Gain Armor and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let sapArrow = Ability(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill, directDamage: 3, damageKeyword: .stun,
        description: "Deal 3 Stun damage.",
        targetedEffects: []
    )
    static let serratedArrowhead = Ability(
        id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate, directDamage: 6, damageKeyword: .bleed,
        description: "Deal 6 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(6))]
    )
    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill, directDamage: 3, damageKeyword: .bleed,
        description: "Deal 3 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(3))]
    )
    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.\nGain 1 Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    static let shieldScarab = Ability(
        id: "shield-scarab", name: "Shield Scarab", tier: .skill, directDamage: 2, damageKeyword: .poison,
        description: "Gain Block and deal 2 Poison damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 2, 6)),
            TargetedEffect(.poison(2))
        ]
    )
    static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage."
    )
    static let smellingSalts = Ability(
        id: "smelling-salts", name: "Smelling Salts", tier: .basic, directDamage: 0,
        description: "Cleanse Stunned and restore 1 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(.stun, 0)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )
    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill, directDamage: 3, damageKeyword: .holy,
        description: "Deal 3 Holy damage."
    )
    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.20, 6))
        ]
    )
    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage."
    )
    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill, directDamage: 3,
        description: "Deal 3 Physical damage and gain 3 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill, directDamage: 0,
        description: "Gain Armor.",
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.30, 6))]
    )
    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and restore 2 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 2))]
    )
    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        directDamage: 3,
        description: "Deal 3 Physical damage and reduce enemy Armor by half.",
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
    )
    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate, directDamage: 2, damageKeyword: .bleed,
        description: "Gain Armor and deal 2 Bleed damage.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.bleed(2))
        ]
    )
    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill, directDamage: 0,
        description: "Gain 2 Gold and restore 1 Health.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )
    static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let willOWisp = Ability(
        id: "will-o-wisp", name: "Will-o-Wisp", tier: .basic, directDamage: 1, damageKeyword: .burn,
        description: "Deal 1 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let wish = Ability(
        id: "wish", name: "Wish", tier: .ultimate, directDamage: 0,
        description: "Gain 3 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let wishingPotion = Ability(
        id: "wishing-potion", name: "Wishing Potion", tier: .ultimate, directDamage: 0,
        description: "Gain 3 Gold and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let wishingWell = Ability(
        id: "wishing-well", name: "Wishing Well", tier: .basic, directDamage: 0,
        description: "Gain 2 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))]
    )

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result: [Keyword] = []
        if directDamage > 0 {
            result.append(damageKeyword)
        }
        if let statusApplication {
            result.append(statusApplication.keyword)
        }
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
        }
        return result
    }

    var summary: String {
        description
    }
}

struct AbilityLoadout: Hashable {
    let basic: Ability?
    let skill: Ability?
    let ultimate: Ability?

    init(
        basic: Ability? = nil,
        skill: Ability? = nil,
        ultimate: Ability? = nil
    ) {
        self.basic = basic
        self.skill = skill
        self.ultimate = ultimate
    }

    var abilities: [Ability] {
        [basic, skill, ultimate].compactMap(\.self)
    }

    func ability(for tier: AbilityTier) -> Ability? {
        switch tier {
        case .basic:
            return basic
        case .skill:
            return skill
        case .ultimate:
            return ultimate
        }
    }

    func selecting(_ ability: Ability) -> AbilityLoadout {
        switch ability.tier {
        case .basic:
            return AbilityLoadout(basic: ability, skill: skill, ultimate: ultimate)
        case .skill:
            return AbilityLoadout(basic: basic, skill: ability, ultimate: ultimate)
        case .ultimate:
            return AbilityLoadout(basic: basic, skill: skill, ultimate: ability)
        }
    }

    func unlocked(for progression: CombatantProgression) -> AbilityLoadout {
        AbilityLoadout(
            basic: progression.unlocks(.basic) ? basic : nil,
            skill: progression.unlocks(.skill) ? skill : nil,
            ultimate: progression.unlocks(.ultimate) ? ultimate : nil
        )
    }
}

struct AbilityChoices: Hashable {
    let basics: [Ability]
    let skills: [Ability]
    let ultimates: [Ability]
    let selected: AbilityLoadout

    init(
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability],
        selected: AbilityLoadout? = nil,
        fillsMissingSelections: Bool = true
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        let defaultLoadout = AbilityLoadout(
            basic: basics.first,
            skill: skills.first,
            ultimate: ultimates.first
        )
        let selectedLoadout = selected ?? defaultLoadout
        if fillsMissingSelections {
            self.selected = AbilityChoices.resolvedLoadout(
                selectedLoadout,
                basics: basics,
                skills: skills,
                ultimates: ultimates
            )
        } else {
            self.selected = AbilityChoices.resolvedLoadoutPreservingEmptyTiers(
                selectedLoadout,
                basics: basics,
                skills: skills,
                ultimates: ultimates
            )
        }
    }

    init(abilities: [Ability]) {
        self.init(
            basics: abilities.filter { $0.tier == .basic },
            skills: abilities.filter { $0.tier == .skill },
            ultimates: abilities.filter { $0.tier == .ultimate }
        )
    }

    func abilities(for tier: AbilityTier) -> [Ability] {
        switch tier {
        case .basic:
            return basics
        case .skill:
            return skills
        case .ultimate:
            return ultimates
        }
    }

    func withSelectedLoadout(_ loadout: AbilityLoadout) -> AbilityChoices {
        AbilityChoices(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout
        )
    }

    func withSelectedLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> AbilityChoices {
        AbilityChoices(
            basics: basics,
            skills: skills,
            ultimates: ultimates,
            selected: loadout,
            fillsMissingSelections: false
        )
    }

    private static func resolvedLoadout(
        _ loadout: AbilityLoadout,
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability]
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbility(loadout.basic, in: basics),
            skill: selectedAbility(loadout.skill, in: skills),
            ultimate: selectedAbility(loadout.ultimate, in: ultimates)
        )
    }

    private static func resolvedLoadoutPreservingEmptyTiers(
        _ loadout: AbilityLoadout,
        basics: [Ability],
        skills: [Ability],
        ultimates: [Ability]
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: selectedAbilityIfPresent(loadout.basic, in: basics),
            skill: selectedAbilityIfPresent(loadout.skill, in: skills),
            ultimate: selectedAbilityIfPresent(loadout.ultimate, in: ultimates)
        )
    }

    private static func selectedAbility(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else {
            return choices.first
        }

        return choices.first { $0.id == ability.id } ?? choices.first
    }

    private static func selectedAbilityIfPresent(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else { return nil }
        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
