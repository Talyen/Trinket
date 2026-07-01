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
    case shield(Keyword, Int, Int)
    case mitigation(Keyword, Double, Int)
    case instantHeal(Keyword, Int)
    case leech(Keyword, Double, Int)
    case resourceGain(Keyword, Int)
    case cleanse(Keyword?, Int)

    static let bleedDoTTickCount = 3

    var keyword: Keyword {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case let .prevention(k, _): return k
        case let .shield(k, _, _): return k
        case let .mitigation(k, _, _): return k
        case let .instantHeal(k, _): return k
        case let .leech(k, _, _): return k
        case let .resourceGain(k, _): return k
        case let .cleanse(k?, _): return k
        case .cleanse(nil, _): return .health
        }
    }

    var potency: Int? {
        switch self {
        case let .burn(p), let .poison(p), let .bleed(p): return p
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
        case .burn, .poison, .instantHeal, .resourceGain: return 0
        }
    }

    var isInstant: Bool {
        switch self {
        case .instantHeal, .resourceGain: return true
        default: return false
        }
    }

    var isDecayingDoT: Bool {
        switch self {
        case .burn, .poison: return true
        default: return false
        }
    }

    var isBleed: Bool {
        if case .bleed = self { return true }
        return false
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
            return "Deals \(amount) Burn damage"
        case let .poison(amount):
            return "Deals \(amount) Poison damage"
        case let .bleed(amount):
            return "Deals \(amount) Bleed damage"
        case let .prevention(k, d):
            return "\(k.rawValue) for \(d) actions"
        case let .shield(k, b, d):
            return "\(k.rawValue) \(b) for \(d) ticks"
        case let .mitigation(k, p, d):
            return "\(k.rawValue) \(Int(p * 100))% for \(d) ticks"
        case let .instantHeal(k, a):
            return "\(k.rawValue) \(a)"
        case let .leech(k, p, d):
            return "\(k.rawValue) \(Int(p * 100))% for \(d) ticks"
        case let .resourceGain(k, a):
            return "\(k.rawValue) \(a)"
        case let .cleanse(k?, d):
            return "Cleanse \(k.rawValue) for \(d) ticks"
        case .cleanse(nil, let d):
            return "Cleanse all for \(d) ticks"
        }
    }

    static func defaultTarget(for effect: Effect) -> EffectTarget {
        switch effect {
        case .burn, .poison, .bleed, .prevention:
            return .abilityTarget
        case .shield, .mitigation, .instantHeal, .leech, .resourceGain, .cleanse:
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

    var keyword: Keyword {
        effect.keyword
    }

    var summary: String {
        switch effect {
        case .burn, .poison:
            return "\(effect.keyword.rawValue) active"
        case let .bleed(potency):
            return "\(effect.keyword.rawValue): \(potency) damage, \(remainingTicks) ticks left"
        case let .prevention(k, _):
            return "\(k.rawValue): \(remainingTicks) actions prevented"
        case let .shield(k, b, _):
            return "\(k.rawValue): \(b) buffer, \(remainingTicks) ticks left"
        case let .mitigation(k, p, _):
            return "\(k.rawValue): \(Int(p * 100))% mitigation, \(remainingTicks) ticks left"
        case let .leech(k, p, _):
            return "\(k.rawValue): \(Int(p * 100))% leech, \(remainingTicks) ticks left"
        case let .cleanse(k?, _):
            return "Cleanse \(k.rawValue): \(remainingTicks) ticks left"
        case .cleanse(nil, _):
            return "Cleanse all: \(remainingTicks) ticks left"
        case .instantHeal, .resourceGain:
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
        statusApplication: StatusApplication? = nil,
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.directDamage = directDamage
        self.damageKeyword = damageKeyword
        self.statusApplication = statusApplication
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
    }

    static let acidPotion = Ability(id: "acid-potion", name: "Acid Potion", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let antivenomPotion = Ability(id: "antivenom-potion", name: "Antivenom Potion", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let anvil = Ability(id: "anvil", name: "Anvil", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let apple = Ability(id: "apple", name: "Apple", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.instantHeal(.health, 1)])
    static let bash = Ability(id: "bash", name: "Bash", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let blackjack = Ability(id: "blackjack", name: "Blackjack", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let blessedAegis = Ability(id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate, directDamage: 6, damageKeyword: .holy, statusApplication: nil, effects: [.shield(.block, 3, 2)])
    static let block = Ability(id: "block", name: "Block", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let bloodOffering = Ability(id: "blood-offering", name: "Blood Offering", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let bloodthorn = Ability(id: "bloodthorn", name: "Bloodthorn", tier: .ultimate, directDamage: 6, damageKeyword: .nature, statusApplication: nil, effects: [.poison(4), .instantHeal(.health, 2)])
    static let bountyShot = Ability(id: "bounty-shot", name: "Bounty Shot", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let bread = Ability(id: "bread", name: "Bread", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.instantHeal(.health, 1)])
    static let briarShield = Ability(id: "briar-shield", name: "Briar Shield", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 2, 2)])
    static let burningBlade = Ability(id: "burning-blade", name: "Burning Blade", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let cauterize = Ability(id: "cauterize", name: "Cauterize", tier: .skill, directDamage: 3, damageKeyword: .burn, statusApplication: nil, effects: [.burn(4)])
    static let cinderbloom = Ability(id: "cinderbloom", name: "Cinderbloom", tier: .skill, directDamage: 3, damageKeyword: .burn, statusApplication: nil, effects: [.burn(4)])
    static let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.cleanse(nil, 3)])
    static let coldSnap = Ability(id: "cold-snap", name: "Cold Snap", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.freeze, 1)])
    static let combustion = Ability(id: "combustion", name: "Combustion", tier: .ultimate, directDamage: 6, damageKeyword: .burn, statusApplication: nil, effects: [.burn(8)])
    static let concussiveShot = Ability(id: "concussive-shot", name: "Concussive Shot", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.stun, 1)])
    static let crystalBulwark = Ability(id: "crystal-bulwark", name: "Crystal Bulwark", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 4, 3)])
    static let darkPact = Ability(id: "dark-pact", name: "Dark Pact", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let exorcism = Ability(id: "exorcism", name: "Exorcism", tier: .ultimate, directDamage: 6, damageKeyword: .holy, statusApplication: nil)
    static let fangs = Ability(id: "fangs", name: "Fangs", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let faustianBargain = Ability(id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let fireArrow = Ability(id: "fire-arrow", name: "Fire Arrow", tier: .basic, directDamage: 1, damageKeyword: .burn, statusApplication: nil, effects: [.burn(2)])
    static let fireball = Ability(id: "fireball", name: "Fireball", tier: .skill, directDamage: 3, damageKeyword: .burn, statusApplication: nil, effects: [.burn(4)])
    static let frostbolt = Ability(id: "frostbolt", name: "Frostbolt", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.freeze, 1)])
    static let gamblersShot = Ability(id: "gamblers-shot", name: "Gambler's Shot", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let glacialWard = Ability(id: "glacial-ward", name: "Glacial Ward", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 4, 3)])
    static let gold = Ability(id: "gold", name: "Gold", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 1)])
    static let goldenPlate = Ability(id: "golden-plate", name: "Golden Plate", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 4)])
    static let goldenRetriever = Ability(id: "golden-retriever", name: "Golden Retriever", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 4)])
    static let graspingVines = Ability(id: "grasping-vines", name: "Grasping Vines", tier: .skill, directDamage: 3, damageKeyword: .nature, statusApplication: nil, effects: [.prevention(.stun, 1)])
    static let haste = Ability(id: "haste", name: "Haste", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let heal = Ability(id: "heal", name: "Heal", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let healthPotion = Ability(id: "health-potion", name: "Health Potion", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.instantHeal(.health, 3)])
    static let hemorrhage = Ability(id: "hemorrhage", name: "Hemorrhage", tier: .ultimate, directDamage: 6, damageKeyword: .bleed, statusApplication: nil, effects: [.bleed(6), .leech(.leech, 0.25, 3)])
    static let holyRadiance = Ability(id: "holy-radiance", name: "Holy Radiance", tier: .ultimate, directDamage: 6, damageKeyword: .holy, statusApplication: nil)
    static let iceShot = Ability(id: "ice-shot", name: "Ice Shot", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let judgment = Ability(id: "judgment", name: "Judgment", tier: .ultimate, directDamage: 6, damageKeyword: .holy, statusApplication: nil, effects: [.prevention(.stun, 1)])
    static let kindling = Ability(id: "kindling", name: "Kindling", tier: .basic, directDamage: 1, damageKeyword: .burn, statusApplication: nil, effects: [.burn(2)])
    static let libraryOwl = Ability(id: "library-owl", name: "Library Owl", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let lightningArrow = Ability(id: "lightning-arrow", name: "Lightning Arrow", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let lightningBolt = Ability(id: "lightning-bolt", name: "Lightning Bolt", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let luckPotion = Ability(id: "luck-potion", name: "Luck Potion", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let manaBerries = Ability(id: "mana-berries", name: "Mana Berries", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 1)])
    static let manaCrystals = Ability(id: "mana-crystals", name: "Mana Crystals", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 1)])
    static let manaMoth = Ability(id: "mana-moth", name: "Mana Moth", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let manaPotion = Ability(id: "mana-potion", name: "Mana Potion", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let manaShield = Ability(id: "mana-shield", name: "Mana Shield", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 2, 2)])
    static let meteor = Ability(id: "meteor", name: "Meteor", tier: .ultimate, directDamage: 6, damageKeyword: .burn, statusApplication: nil, effects: [.burn(8)])
    static let mixedPotion = Ability(id: "mixed-potion", name: "Mixed Potion", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let moltenBulwark = Ability(id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate, directDamage: 6, damageKeyword: .burn, statusApplication: nil, effects: [.burn(8)])
    static let packTactics = Ability(id: "pack-tactics", name: "Pack Tactics", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let panaceaPotion = Ability(id: "panacea-potion", name: "Panacea Potion", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let phoenixFeather = Ability(id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate, directDamage: 6, damageKeyword: .burn, statusApplication: nil, effects: [.burn(8)])
    static let pixie = Ability(id: "pixie", name: "Pixie", tier: .ultimate, directDamage: 6, damageKeyword: .nature, statusApplication: nil, effects: [.instantHeal(.health, 2)])
    static let placeholderCard = Ability(id: "placeholder-card", name: "Placeholder Card", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let plateMail = Ability(id: "plate-mail", name: "Plate Mail", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 3, 2)])
    static let poisonDagger = Ability(id: "poison-dagger", name: "Poison Dagger", tier: .skill, directDamage: 3, damageKeyword: .poison, statusApplication: nil, effects: [.poison(4)])
    static let prayer = Ability(id: "prayer", name: "Prayer", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.mitigation(.armor, 0.50, 2), .instantHeal(.health, 2)])
    static let raiseSkeleton = Ability(id: "raise-skeleton", name: "Raise Skeleton", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let rayOfFrost = Ability(id: "ray-of-frost", name: "Ray of Frost", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.freeze, 1)])
    static let roulette = Ability(id: "roulette", name: "Roulette", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let sanctifiedPlate = Ability(id: "sanctified-plate", name: "Sanctified Plate", tier: .ultimate, directDamage: 6, damageKeyword: .holy, statusApplication: nil)
    static let sapArrow = Ability(id: "sap-arrow", name: "Sap Arrow", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.stun, 1)])
    static let serratedArrowhead = Ability(id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate, directDamage: 6, damageKeyword: .bleed, statusApplication: nil, effects: [.bleed(6)])
    static let serratedEdge = Ability(id: "serrated-edge", name: "Serrated Edge", tier: .skill, directDamage: 3, damageKeyword: .bleed, statusApplication: nil, effects: [.bleed(3)])
    static let shieldBash = Ability(id: "shield-bash", name: "Shield Bash", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.prevention(.stun, 1)])
    static let shieldScarab = Ability(id: "shield-scarab", name: "Shield Scarab", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let slash = Ability(id: "slash", name: "Slash", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let smellingSalts = Ability(id: "smelling-salts", name: "Smelling Salts", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.cleanse(.stun, 3)])
    static let smite = Ability(id: "smite", name: "Smite", tier: .skill, directDamage: 3, damageKeyword: .holy, statusApplication: nil)
    static let spikedShield = Ability(id: "spiked-shield", name: "Spiked Shield", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.shield(.block, 2, 2)])
    static let stab = Ability(id: "stab", name: "Stab", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let steal = Ability(id: "steal", name: "Steal", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let stoneskinPotion = Ability(id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil, effects: [.mitigation(.armor, 0.25, 3)])
    static let sunburst = Ability(id: "sunburst", name: "Sunburst", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil)
    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        directDamage: 3,
        damageKeyword: .physical,
        statusApplication: nil,
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.25, 2), target: .enemy)]
    )
    static let thornMail = Ability(id: "thorn-mail", name: "Thorn Mail", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.mitigation(.armor, 0.25, 3)])
    static let tithe = Ability(id: "tithe", name: "Tithe", tier: .skill, directDamage: 3, damageKeyword: .physical, statusApplication: nil)
    static let venomArrow = Ability(id: "venom-arrow", name: "Venom Arrow", tier: .skill, directDamage: 3, damageKeyword: .poison, statusApplication: nil, effects: [.poison(4)])
    static let venomFangs = Ability(id: "venom-fangs", name: "Venom Fangs", tier: .skill, directDamage: 3, damageKeyword: .poison, statusApplication: nil, effects: [.poison(4)])
    static let willOWisp = Ability(id: "will-o-wisp", name: "Will-o-Wisp", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil)
    static let wish = Ability(id: "wish", name: "Wish", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 3)])
    static let wishingPotion = Ability(id: "wishing-potion", name: "Wishing Potion", tier: .ultimate, directDamage: 6, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 3)])
    static let wishingWell = Ability(id: "wishing-well", name: "Wishing Well", tier: .basic, directDamage: 1, damageKeyword: .physical, statusApplication: nil, effects: [.resourceGain(.gold, 2)])

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result = [damageKeyword]
        if let statusApplication {
            result.append(statusApplication.keyword)
        }
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
        }
        return result
    }

    var summary: String {
        var text = "\(directDamage) \(damageKeyword.rawValue) damage"
        let effectTexts = targetedEffects.map(\.effect.summary)
        if !effectTexts.isEmpty {
            text += ". Apply " + effectTexts.joined(separator: ", ") + "."
        } else if let statusApplication {
            text += ". Apply \(statusApplication.summary)."
        }
        return text
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
        selected: AbilityLoadout? = nil
    ) {
        self.basics = basics
        self.skills = skills
        self.ultimates = ultimates
        let defaultLoadout = AbilityLoadout(
            basic: basics.first,
            skill: skills.first,
            ultimate: ultimates.first
        )
        self.selected = AbilityChoices.resolvedLoadout(
            selected ?? defaultLoadout,
            basics: basics,
            skills: skills,
            ultimates: ultimates
        )
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

    private static func selectedAbility(_ ability: Ability?, in choices: [Ability]) -> Ability? {
        guard let ability else {
            return choices.first
        }

        return choices.first { $0.id == ability.id } ?? choices.first
    }
}
