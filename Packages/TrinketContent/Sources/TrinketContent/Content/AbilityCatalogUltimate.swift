import Foundation
import TrinketCore

public enum AbilityCatalogUltimate {
    public static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purge(nil))]
    )
    public static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate,
        description: "Gain Block and deal 3 Freeze damage.",
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6))
        ]
    )
    public static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    public static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        description: "Gain Block and deal 3 Burn damage.",
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.burn(3))
        ]
    )
    public static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain Armor and deal 2 Bleed damage.",
        damageComponents: [DamageComponent(2, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.bleed(2))
        ]
    )

    public static let all: [Ability] = [
        exorcism,
        glacialWard,
        judgment,
        moltenBulwark,
        thornMail
    ] + AbilityCatalogUltimateGenerated.all
}
