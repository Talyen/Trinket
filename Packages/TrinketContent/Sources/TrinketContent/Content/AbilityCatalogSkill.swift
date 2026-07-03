import Foundation
import TrinketCore

public enum AbilityCatalogSkill {
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
            TargetedEffect(.mitigation(.armor, 0.25, 6))
        ]
    )
    public static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    public static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.shield(.block, 2, 6))
        ]
    )
    public static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    public static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.20, 6))
        ]
    )
    public static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
    )

    public static let all: [Ability] = [
        antivenomPotion,
        bloodOffering,
        briarShield,
        cleanse,
        manaPotion,
        prayer,
        spikedShield,
        sunderArmor
    ] + AbilityCatalogSkillGenerated.all
}
