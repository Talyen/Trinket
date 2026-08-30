import Foundation
import TrinketCore

enum AbilityCatalogSkill {
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
            DamageComponent(4, keyword: .bleed),
        ],
    )

    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .skill,
        description: "Deal 3 Physical damage or steal 3 Gold. If the enemy is Marked, gain both.",
        outcomeBranches: [
            AbilityOutcomeBranch(
                damageComponents: [DamageComponent(3, keyword: .physical)],
                targetedEffects: [TargetedEffect(.resourceGain(.gold, 3), condition: .enemyMarked)],
            ),
            AbilityOutcomeBranch(
                damageComponents: [
                    DamageComponent(0, keyword: .physical, bonusAmount: 3, condition: .enemyMarked),
                ],
                targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))],
            ),
        ],
    )

    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(1)),
        ],
    )

    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
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
        description: "Lose 3 Health. Draw 2 cards.",
        damageComponents: [DamageComponent(3, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.drawCards(2))],
    )

    static let fireball = AbilityBuilder.directHit(
        id: "fireball", name: "Fireball", tier: .skill,
        amount: 3, keyword: .burn,
    )

    static let frostbolt = AbilityBuilder.directHit(
        id: "frostbolt", name: "Frostbolt", tier: .skill,
        amount: 3, keyword: .freeze,
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
        damageComponents: [DamageComponent(2, keyword: .poison)],
    )

    static let pounce = Ability(
        id: "pounce", name: "Pounce", tier: .skill,
        description: "Deal 3 Stun damage. Doubled if played on the first turn.",
        damageComponents: [
            DamageComponent(3, keyword: .stun, bonusAmount: 3, condition: .firstTurn),
        ],
    )

    static let predatorsFocus = Ability(
        id: "predators-focus", name: "Predator's Focus", tier: .skill,
        description: "Mark the enemy. Your next attack is a guaranteed Critical Hit.",
        targetedEffects: [
            TargetedEffect(.marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration), target: .enemy),
            TargetedEffect(.nextStrikeCritical, target: .actor),
        ],
    )

    static let sapArrow = AbilityBuilder.directHit(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill,
        amount: 3, keyword: .stun,
        extras: [TargetedEffect(.resourceGain(.mana, 1), target: .actor)],
    )

    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.damageReductionPercent(0.50, 2), target: .enemy),
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
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(2)),
        ],
    )

    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))],
    )

    static let stoneskinPotion = AbilityBuilder.buffOnly(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        effects: [.shield(.block, 4)],
    )

    static let sunder = Ability(
        id: "sunder",
        name: "Sunder",
        tier: .skill,
        damageComponents: [DamageComponent(4, keyword: .physical)],
        targetedEffects: [TargetedEffect(.halveShield(.block), target: .enemy)],
    )

    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .holy)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 3)]),
        ],
    )

    static let venomFangs = AbilityBuilder.directHit(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        amount: 2, keyword: .poison,
        hasLeech: true,
    )

    static let all: [Ability] = [
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
