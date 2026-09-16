import Foundation
import TrinketCore

// swiftlint:disable:next type_body_length - AbilityCatalog is the single ability table; tiers group by MARK section
public enum AbilityCatalog {
    // MARK: - Basic

    public static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))],
    )

    public static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic,
        description: "Deal 2 Stun damage. If this Stuns the enemy, deal 2 Physical damage.",
        damageComponents: [
            DamageComponent(2, keyword: .stun),
            DamageComponent(2, keyword: .physical, condition: .enemyStunned),
        ],
    )

    public static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .stun)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2), condition: .enemyStunned),
        ],
        stealsGold: true,
    )

    public static let block = Ability(
        id: "block", name: "Block", tier: .basic,
        effects: [.shield(.block, 3)],
    )

    public static let causticJab = Ability(
        id: "caustic-jab", name: "Caustic Jab", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.halveShield(.block), target: .enemy),
        ],
    )

    public static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic,
        directDamage: 1, damageKeyword: .bleed,
        hasLeech: true,
    )

    public static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [
            DamageComponent(1, keyword: .burn, bonusAmount: 1, condition: .enemyBurning),
        ],
    )

    public static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        description: "Deal 2 Freeze damage. If this Freezes the enemy, deal 2 Physical damage.",
        damageComponents: [
            DamageComponent(2, keyword: .freeze),
            DamageComponent(2, keyword: .physical, condition: .enemyFrozen),
        ],
    )

    public static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic,
        description: "Deal 1 Burn damage. Your next Burn card deals +1 Burn damage.",
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.nextBurnBonus(1), target: .actor)],
    )

    public static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.resourceGain(.mana, 2)),
        ],
    )

    public static let maul = Ability(
        id: "maul", name: "Maul", tier: .basic,
        description: "Deal 2 Stun or Bleed damage at random.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .stun)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .bleed)]),
        ],
    )

    public static let pixieDust = Ability(
        id: "pixie-dust", name: "Pixie Dust", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    public static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 1, 2))],
    )

    public static let rendingSlash = Ability(
        id: "rending-slash", name: "Rend", tier: .basic,
        directDamage: 2, damageKeyword: .bleed,
    )

    public static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .stun)],
        targetedEffects: [TargetedEffect(.shield(.block, 1))],
    )

    public static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic,
        description: "Deal 2 to 3 Physical damage.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .physical)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .physical)]),
        ],
    )

    public static let sniffOut = Ability(
        id: "sniff-out", name: "Sniff Out", tier: .basic,
        description: "Your party's next attack deals 3 additional Physical damage.",
        targetedEffects: [TargetedEffect(.partyPhysicalBonus(3))],
    )

    public static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic,
        description: "Deal 2 Physical damage with a +25% chance to Critically Hit.",
        damageComponents: [DamageComponent(2, keyword: .physical)],
        criticalChanceBonus: 0.25,
    )

    public static let stargaze = Ability(
        id: "stargaze", name: "Stargaze", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    public static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .basic,
        directDamage: 2, damageKeyword: .poison,
    )

    // MARK: - Skill

    public static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.halveShield(.block), target: .enemy),
        ],
    )

    public static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [
            DamageComponent(1, keyword: .physical, target: .actor),
            DamageComponent(3, keyword: .bleed),
        ],
    )

    public static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .skill,
        description: "Deal 3 Physical damage and Steal 2 Gold.",
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    public static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 1)),
            TargetedEffect(.thorns(3)),
        ],
    )

    public static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        description: "Deal 3 Burn or Poison damage at random.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .poison)]),
        ],
    )

    public static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanseRandom),
            TargetedEffect(.instantHeal(.health, 3)),
        ],
    )

    public static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        description: "Deal 2 Freeze damage. Restore 1 Mana if the enemy is Frozen.",
        damageComponents: [DamageComponent(2, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1), condition: .enemyFrozen),
        ],
    )

    public static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        description: "Pay 3 Health. Draw 2 cards.",
        damageComponents: [DamageComponent(3, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.drawCards(2))],
    )

    public static let fireball = Ability(
        id: "fireball", name: "Fireball", tier: .skill,
        description: "Deal 2 to 4 Burn damage.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .burn)]),
        ],
    )

    public static let frostbolt = Ability(
        id: "frostbolt", name: "Frostbolt", tier: .skill,
        directDamage: 3, damageKeyword: .freeze,
    )

    public static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .skill,
        description: "Gain 2 Block. Deal 2 Freeze damage next time you're hit.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.onHitDamage(.freeze, 2)),
        ],
    )

    public static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 6))],
    )

    public static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 3))],
    )

    public static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [TargetedEffect(.convertManaToBlock)],
    )

    public static let poisonDagger = Ability(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill,
        description: "Deal 2 Poison damage. If the target is Poisoned, deal 2 Physical damage.",
        damageComponents: [
            DamageComponent(2, keyword: .poison),
            DamageComponent(2, keyword: .physical, condition: .enemyPoisoned),
        ],
    )

    public static let pounce = Ability(
        id: "pounce", name: "Pounce", tier: .skill,
        description: "Deal 3 Stun damage, doubled on the first combat turn.",
        damageComponents: [
            DamageComponent(3, keyword: .stun, bonusAmount: 3, condition: .firstTurn),
        ],
    )

    public static let predatorsFocus = Ability(
        id: "predators-focus", name: "Predator's Focus", tier: .skill,
        description: "Your next attack is guaranteed to Critically Hit and Leech.",
        targetedEffects: [
            TargetedEffect(.nextStrikeCritical, target: .actor),
            TargetedEffect(.nextStrikeLeech, target: .actor),
        ],
    )

    public static let sapArrow = Ability(
        id: "sap-arrow", name: "Bandit's Arrow", tier: .skill,
        description: "Deal 3 Stun damage and steal 2 Gold.",
        damageComponents: [DamageComponent(3, keyword: .stun)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    public static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        description: "Deal 2 Bleed damage. Reduces the Health restored to enemies by 25% for 3 turns.",
        damageComponents: [DamageComponent(2, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.healingReductionPercent(0.25, 3), target: .enemy),
        ],
    )

    public static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        description: "Deal 4 Holy damage and Purge a positive status effect from the enemy.",
        damageComponents: [DamageComponent(4, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purgeRandom, target: .enemy)],
    )

    public static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(2)),
        ],
    )

    public static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    public static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        effects: [.shield(.block, 4)],
    )

    public static let sunder = Ability(
        id: "sunder",
        name: "Sunder",
        tier: .skill,
        damageComponents: [DamageComponent(4, keyword: .physical)],
        targetedEffects: [TargetedEffect(.halveShield(.block), target: .enemy)],
    )

    public static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill,
        description: "Deal 2 Holy damage and Steal 2 Gold.",
        damageComponents: [DamageComponent(2, keyword: .holy)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    public static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        directDamage: 2, damageKeyword: .poison,
        hasLeech: true,
    )

    // MARK: - Ultimate

    public static let avatarOfJustice = Ability(
        id: "avatar-of-justice", name: "Avatar", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.avatar(holyDamage: 6, blockPerTurn: 0, turns: 2)),
        ],
    )

    public static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        description: "Your Hero and Companion each gain 4 Block and deal 4 Holy damage the next time they’re hit.",
        targetedEffects: [TargetedEffect(.blessedAegis(block: 4, holyDamage: 4))],
    )

    public static let blizzard = Ability(
        id: "blizzard", name: "Blizzard", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 4, 2))],
    )

    public static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .bleed),
            DamageComponent(2, keyword: .poison),
        ],
        hasLeech: true,
    )

    public static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        description: "Deal 6 Burn damage. If the enemy is Burning, detonate all its remaining Burn at once.",
        damageComponents: [
            DamageComponent(6, keyword: .burn),
        ],
        targetedEffects: [
            TargetedEffect(.detonateDoT(.burn, 1), target: .enemy, condition: .enemyBurning),
        ],
    )

    public static let astralArrow = Ability(
        id: "astral-arrow", name: "Astral Arrow", tier: .ultimate,
        description: "Deal 7 Burn, Freeze, or Bleed damage.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .freeze)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .bleed)]),
        ],
    )

    public static let earthquake = Ability(
        id: "earthquake", name: "Earthquake", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.stun, 4, 2))],
    )

    public static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .physical, target: .actor),
            DamageComponent(4, keyword: .burn),
        ],
        targetedEffects: [
            TargetedEffect(.drawCards(1), target: .actor),
        ],
    )

    public static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        description: "Gain 8 Block and 5 Gold.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 8)),
            TargetedEffect(.resourceGain(.gold, 5)),
        ],
    )

    public static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        damageComponents: [DamageComponent(4, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.hemorrhage(4)),
        ],
    )

    public static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        description: "Roll a 12-sided die. Deal that much Holy, Freeze, or Physical damage, chosen at random.",
        outcomeBranches: (1 ... 12).flatMap { amount in
            [Keyword.holy, .freeze, .physical].map { keyword in
                AbilityOutcomeBranch(damageComponents: [DamageComponent(amount, keyword: keyword)])
            }
        },
    )

    public static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        repeatsManaEmpowerment: true,
    )

    public static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4)),
            TargetedEffect(.onHitDamage(.burn, 3)),
        ],
    )

    public static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        description: "Deal 3 Physical damage. Draw and play 1 card from your ally's deck.",
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [
            TargetedEffect(.drawAndPlayCards(1)),
        ],
    )

    public static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        description: "Cleanse the ally with the most debuffs. Restore 3 Health plus 2 per debuff cleansed to the living ally with the lowest Health.",
        targetedEffects: [
            TargetedEffect(.panacea(baseHeal: 3, healPerDebuff: 2)),
        ],
    )

    public static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.revive(1), target: .defeatedAlly),
        ],
    )

    public static let shadowstep = Ability(
        id: "shadowstep", name: "Shadowstep", tier: .ultimate,
        description: "Draw 1 card. Dodge the next attack. Your next attack is a guaranteed Critical Hit.",
        targetedEffects: [
            TargetedEffect(.drawCards(1), target: .actor),
            TargetedEffect(.evadeNextHit, target: .actor),
            TargetedEffect(.nextStrikeCritical, target: .actor),
        ],
    )

    public static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        description: "Deal 6 Holy damage. Restore 3 Health to each ally.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3), target: .eachAlly),
        ],
    )

    public static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain 5 Block and 5 Thorns.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 5)),
            TargetedEffect(.thorns(5)),
        ],
    )

    public static let all: [Ability] = [
        apple,
        bash,
        blackjack,
        block,
        causticJab,
        fangs,
        fireArrow,
        iceShot,
        kindling,
        manaBerries,
        maul,
        pixieDust,
        rayOfFrost,
        rendingSlash,
        shieldBash,
        slash,
        sniffOut,
        stab,
        stargaze,
        venomArrow,
        acidPotion,
        bloodOffering,
        bountyShot,
        briarShield,
        cinderbloom,
        cleanse,
        coldSnap,
        darkPact,
        fireball,
        frostbolt,
        glacialWard,
        heal,
        manaPotion,
        manaShield,
        poisonDagger,
        pounce,
        predatorsFocus,
        sapArrow,
        serratedEdge,
        smite,
        spikedShield,
        steal,
        stoneskinPotion,
        sunder,
        tithe,
        venomFangs,
        avatarOfJustice,
        astralArrow,
        blessedAegis,
        blizzard,
        bloodthorn,
        combustion,
        earthquake,
        faustianBargain,
        goldenPlate,
        hemorrhage,
        luckPotion,
        meteor,
        moltenBulwark,
        packTactics,
        panaceaPotion,
        phoenixFeather,
        shadowstep,
        sunburst,
        thornMail,
    ]

    public static func ability(id: String) -> Ability? {
        AbilityCatalogIndexGenerated.abilitiesByID[id]
    }
}
