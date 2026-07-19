import Foundation
import TrinketCore

enum AbilityCatalogSkill {
    static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.poison(2)),
            TargetedEffect(.halveShield(.block), target: .enemy)
        ],
        manaCost: 1
    )
    static let antivenomPotion = Ability(
        id: "antivenom-potion", name: "Antivenom Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(.poison)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        description: "Lose 2 Health. Deal 4 Bleed damage.",
        damageComponents: [
            DamageComponent(2, keyword: .physical, target: .actor),
            DamageComponent(4, keyword: .bleed)
        ],
        targetedEffects: [TargetedEffect(.bleed(4))]
    )
    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 5)),
            TargetedEffect(.instantHeal(.health, 1))
        ],
        manaCost: 2
    )
    static let cauterize = Ability(
        id: "cauterize", name: "Cauterize", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 2))
        ],
        manaCost: 2
    )
    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 1))
        ],
        manaCost: 2
    )
    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 2))
        ],
        manaCost: 2
    )
    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        damageComponents: [
            DamageComponent(3, keyword: .freeze, bonusAmount: 2, condition: .enemyFrozen)
        ],
        manaCost: 2
    )
    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        description: "Lose 2 Health. Draw 2 cards.",
        damageComponents: [DamageComponent(2, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.drawCards(2))]
    )
    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))],
        manaCost: 1
    )
    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 2)),
            TargetedEffect(.shield(.block, 2))
        ]
    )
    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3)),
            TargetedEffect(.restoreManaOnHit(1, 6))
        ]
    )
    static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    static let predatorsHaste = Ability(
        id: "predators-haste", name: "Predator's Haste", tier: .skill,
        targetedEffects: [
            TargetedEffect(.haste(4)),
            TargetedEffect(.criticalChanceBonus(0.15, 6))
        ]
    )
    static let sageHeal = Ability(
        id: "sage-heal", name: "Sage Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3), target: .lowestHealthAlly)],
        manaCost: 2
    )
    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(3))]
    )
    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .holy)]
    )
    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 4)),
            TargetedEffect(.thorns(.physical, 1, 6))
        ]
    )
    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))],
        criticalChanceBonus: 0.20
    )
    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveShield(.block), target: .enemy)]
    )
    static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .skill,
        damageComponents: [
            DamageComponent(3, keyword: .poison, bonusAmount: 1, condition: .enemyPoisoned)
        ],
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.poison(2)),
            TargetedEffect(.bleed(1), condition: .enemyPoisoned)
        ]
    )

    static let all: [Ability] = [
        acidPotion,
        antivenomPotion,
        bloodOffering,
        briarShield,
        cauterize,
        cinderbloom,
        cleanse,
        coldSnap,
        darkPact,
        heal,
        manaPotion,
        manaShield,
        prayer,
        predatorsHaste,
        sageHeal,
        serratedEdge,
        smite,
        spikedShield,
        steal,
        sunderArmor,
        venomArrow,
        venomFangs
    ] + AbilityCatalogSkillGenerated.all
}
