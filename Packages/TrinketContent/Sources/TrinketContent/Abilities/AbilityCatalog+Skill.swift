import Foundation
import TrinketCore

public extension AbilityCatalog {
    static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.halveShield(.block), target: .enemy),
        ],
    )

    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [
            DamageComponent(1, keyword: .physical, target: .actor),
            DamageComponent(3, keyword: .bleed),
        ],
    )

    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .skill,
        description: "Deal 3 Physical damage and Steal 2 Gold.",
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 1)),
            TargetedEffect(.thorns(3)),
        ],
    )

    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        description: "Deal 3 Burn or Poison damage at random.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .poison)]),
        ],
    )

    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanseRandom),
            TargetedEffect(.instantHeal(.health, 3)),
        ],
    )

    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        description: "Deal 2 Freeze damage. Restore 1 Mana if the enemy is Frozen.",
        damageComponents: [DamageComponent(2, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1), condition: .enemyFrozen),
        ],
    )

    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        description: "Pay 3 Health. Draw 2 cards.",
        damageComponents: [DamageComponent(3, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.drawCards(2))],
    )

    static let fireball = Ability(
        id: "fireball", name: "Fireball", tier: .skill,
        description: "Deal 2 to 4 Burn damage.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .burn)]),
        ],
    )

    static let frostbolt = Ability(
        id: "frostbolt", name: "Frostbolt", tier: .skill,
        directDamage: 3, damageKeyword: .freeze,
    )

    static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .skill,
        description: "Gain 2 Block. Deal 2 Freeze damage next time you're hit.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.onHitDamage(.freeze, 2)),
        ],
    )

    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 6))],
    )

    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 3))],
    )

    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [TargetedEffect(.convertManaToBlock)],
    )

    static let poisonDagger = Ability(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill,
        description: "Deal 2 Poison damage. If the target is Poisoned, deal 2 Physical damage.",
        damageComponents: [
            DamageComponent(2, keyword: .poison),
            DamageComponent(2, keyword: .physical, condition: .enemyPoisoned),
        ],
    )

    static let pounce = Ability(
        id: "pounce", name: "Pounce", tier: .skill,
        description: "Deal 3 Stun damage, doubled on the first combat turn.",
        damageComponents: [
            DamageComponent(3, keyword: .stun, bonusAmount: 3, condition: .firstTurn),
        ],
    )

    static let predatorsFocus = Ability(
        id: "predators-focus", name: "Predator's Focus", tier: .skill,
        description: "Your next attack is guaranteed to Critically Hit and Leech.",
        targetedEffects: [
            TargetedEffect(.nextStrikeCritical, target: .actor),
            TargetedEffect(.nextStrikeLeech, target: .actor),
        ],
    )

    static let sapArrow = Ability(
        id: "sap-arrow", name: "Bandit's Arrow", tier: .skill,
        description: "Deal 3 Stun damage and steal 2 Gold.",
        damageComponents: [DamageComponent(3, keyword: .stun)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        description: "Deal 2 Bleed damage. Reduces the Health restored to enemies by 25% for 3 turns.",
        damageComponents: [DamageComponent(2, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.healingReductionPercent(0.25, 3), target: .enemy),
        ],
    )

    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        description: "Deal 4 Holy damage and Purge a positive status effect from the enemy.",
        damageComponents: [DamageComponent(4, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purgeRandom, target: .enemy)],
    )

    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(2)),
        ],
    )

    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        effects: [.shield(.block, 4)],
    )

    static let sunder = Ability(
        id: "sunder",
        name: "Sunder",
        tier: .skill,
        description: "Halve enemy Block, then deal 4 Physical damage.",
        operations: [
            .effect(TargetedEffect(.halveShield(.block), target: .enemy)),
            .damage(DamageComponent(4, keyword: .physical)),
        ],
    )

    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill,
        description: "Deal 2 Holy damage and Steal 2 Gold.",
        damageComponents: [DamageComponent(2, keyword: .holy)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
        stealsGold: true,
    )

    static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        directDamage: 2, damageKeyword: .poison,
        hasLeech: true,
    )

    internal static let skillAbilities: [Ability] = [
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
    ]
}
