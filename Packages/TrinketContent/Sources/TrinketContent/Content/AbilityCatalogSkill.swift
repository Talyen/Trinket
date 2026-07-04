import Foundation
import TrinketCore

public enum AbilityCatalogSkill {
    public static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.poison(2)),
            TargetedEffect(.halveMitigation(.armor), target: .enemy)
        ],
        manaCost: 1
    )
    public static let antivenomPotion = Ability(
        id: "antivenom-potion", name: "Antivenom Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(.poison)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    public static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )
    public static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.instantHeal(.health, 1))
        ],
        manaCost: 2
    )
    public static let cauterize = Ability(
        id: "cauterize", name: "Cauterize", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 2))
        ],
        manaCost: 2
    )
    public static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 1))
        ],
        manaCost: 2
    )
    public static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 2))
        ],
        manaCost: 2
    )
    public static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        damageComponents: [
            DamageComponent(3, keyword: .freeze, bonusAmount: 2, condition: .enemyFrozen)
        ],
        manaCost: 2
    )
    public static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff)
        ],
        manaCost: 2
    )
    public static let gravePact = Ability(
        id: "grave-pact", name: "Grave Pact", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff),
            TargetedEffect(.purge(nil), target: .enemy)
        ],
        manaCost: 2
    )
    public static let graspingVines = Ability(
        id: "grasping-vines", name: "Grasping Vines", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .nature)],
        targetedEffects: [
            TargetedEffect(.bleed(1)),
            TargetedEffect(.instantHeal(.health, 1))
        ],
        manaCost: 2
    )
    public static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))],
        manaCost: 1
    )
    public static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 2)),
            TargetedEffect(.shield(.block, 2, 6))
        ]
    )
    public static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.restoreManaOnHit(1, 6))
        ]
    )
    public static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    public static let predatorsHaste = Ability(
        id: "predators-haste", name: "Predator's Haste", tier: .skill,
        targetedEffects: [
            TargetedEffect(.haste(4)),
            TargetedEffect(.criticalChanceBonus(0.10, 6))
        ]
    )
    public static let sageHeal = Ability(
        id: "sage-heal", name: "Sage Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3), target: .lowestHealthAlly)],
        manaCost: 2
    )
    public static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(3))],
        criticalChanceBonus: 0.15
    )
    public static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        damageComponents: [
            DamageComponent(3, keyword: .holy, bonusAmount: 1, condition: .enemyStunnedOrFrozen)
        ]
    )
    public static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 2, 6)),
            TargetedEffect(.mitigation(.armor, 0.15, 6)),
            TargetedEffect(.thorns(.physical, 1, 6))
        ]
    )
    public static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))],
        criticalChanceBonus: 0.20
    )
    public static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
    )
    public static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .skill,
        damageComponents: [
            DamageComponent(3, keyword: .poison, bonusAmount: 1, condition: .enemyPoisoned)
        ],
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    public static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.poison(3)),
            TargetedEffect(.bleed(1), condition: .enemyPoisoned)
        ]
    )

    public static let all: [Ability] = [
        acidPotion,
        antivenomPotion,
        bloodOffering,
        briarShield,
        cauterize,
        cinderbloom,
        cleanse,
        coldSnap,
        darkPact,
        gravePact,
        graspingVines,
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
