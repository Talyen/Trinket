import Foundation
import TrinketCore

enum AbilityCatalogSkill {
    static let acidPotion = AbilityBuilder.directHit(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        amount: 3, keyword: .poison
    )

    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [
            DamageComponent(1, keyword: .physical, target: .actor),
            DamageComponent(4, keyword: .bleed),
        ],
        targetedEffects: [TargetedEffect(.bleed(4))]
    )

    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .skill,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .physical)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 3)]),
        ]
    )

    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(1)),
        ]
    )

    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .poison)]),
        ]
    )

    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanseRandom),
            TargetedEffect(.instantHeal(.health, 2)),
        ]
    )

    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1), condition: .enemyFrozen),
        ]
    )

    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        description: "Lose 1 Health. Draw 2 cards.",
        damageComponents: [DamageComponent(1, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.drawCards(2))]
    )

    static let fireball = AbilityBuilder.directHit(
        id: "fireball", name: "Fireball", tier: .skill,
        amount: 2, keyword: .burn
    )

    static let frostbolt = AbilityBuilder.directHit(
        id: "frostbolt", name: "Frostbolt", tier: .skill,
        amount: 3, keyword: .freeze
    )

    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 5))]
    )

    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 3))]
    )

    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [TargetedEffect(.convertManaToBlock)]
    )

    static let poisonDagger = AbilityBuilder.directHit(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill,
        amount: 3, keyword: .poison
    )

    static let pounce = AbilityBuilder.directHit(
        id: "pounce", name: "Pounce", tier: .skill,
        amount: 3, keyword: .stun
    )

    static let predatorsFocus = Ability(
        id: "predators-focus", name: "Predator's Focus", tier: .skill,
        targetedEffects: [TargetedEffect(.nextStrikeCritical)]
    )

    static let sapArrow = AbilityBuilder.directHit(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill,
        amount: 3, keyword: .stun
    )

    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        targetedEffects: [TargetedEffect(.bleed(2))]
    )

    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        damageComponents: [DamageComponent(4, keyword: .holy)]
    )

    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 2)),
            TargetedEffect(.thorns(2)),
        ]
    )

    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )

    static let stoneskinPotion = AbilityBuilder.buffOnly(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        effects: [.shield(.block, 4)]
    )

    static let sunder = Ability(
        id: "sunder",
        name: "Sunder",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveShield(.block), target: .enemy)]
    )

    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .holy)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 3)]),
        ]
    )

    static let venomFangs = AbilityBuilder.directHit(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        amount: 2, keyword: .poison,
        hasLeech: true
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
