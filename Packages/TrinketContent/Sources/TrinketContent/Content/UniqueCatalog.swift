import Foundation
import TrinketCore

/// Authored Unique items. One per base type; the signature affix is bespoke and
/// its title mirrors the item name minus type suffixes (Signet, Locket, …).
enum UniqueCatalog {
    static let definitions: [UniqueItemDefinition] = [
        wardbreaker,
        danceOfBlades,
        bloodfireSignet,
        rimeheartLocket,
    ]

    // MARK: - Wardbreaker (Flail)

    private static let wardbreaker = UniqueItemDefinition(
        id: "wardbreaker",
        displayName: "Wardbreaker",
        baseTypeID: "flail",
        affixes: [
            .bespoke(ItemAffixDefinition(
                id: "wardbreaker",
                title: "Wardbreaker",
                slot: .weapon,
                keywords: [.stun, .holy],
                weight: 0,
                basic: ItemAffixPower(
                    description: "Purge all beneficial status effects when you Stun an enemy. Deal 2 Holy damage for each effect removed.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        control: ControlTriggers(
                            stunPurgeDealHolyPerEffect: 2
                        )
                    )
                ),
                astral: ItemAffixPower(
                    description: "Purge all beneficial status effects when you Stun an enemy. Deal 2 Holy damage for each effect removed.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        control: ControlTriggers(
                            stunPurgeDealHolyPerEffect: 2
                        )
                    )
                )
            )),
            .catalog(id: "dazed"),
            .catalog(id: "concussive"),
            .catalog(id: "sentinel"),
        ]
    )

    // MARK: - Dance of Blades (Leather Armor)

    private static let danceOfBlades = UniqueItemDefinition(
        id: "dance_of_blades",
        displayName: "Dance of Blades",
        baseTypeID: "leather_armor",
        affixes: [
            .bespoke(ItemAffixDefinition(
                id: "dance_of_blades",
                title: "Dance of Blades",
                slot: .armor,
                keywords: [.dodge],
                weight: 0,
                basic: ItemAffixPower(
                    description: "When you Dodge, immediately draw and play a card. If it's a Critical Hit, repeat this effect.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dodge: DodgeTriggers(onDodgeDrawAndPlayCardChainOnCrit: true)
                    )
                ),
                astral: ItemAffixPower(
                    description: "When you Dodge, immediately draw and play a card. If it's a Critical Hit, repeat this effect.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dodge: DodgeTriggers(onDodgeDrawAndPlayCardChainOnCrit: true)
                    )
                )
            )),
            .catalog(id: "riposte"),
            .catalog(id: "untouchable"),
            .catalog(id: "sidestep"),
        ]
    )

    // MARK: - Bloodfire Signet (Ruby Ring)

    private static let bloodfireSignet = UniqueItemDefinition(
        id: "bloodfire_signet",
        displayName: "Bloodfire Signet",
        baseTypeID: "ruby_ring",
        affixes: [
            .bespoke(ItemAffixDefinition(
                id: "bloodfire",
                title: "Bloodfire",
                slot: .accessory,
                keywords: [.burn, .bleed],
                weight: 0,
                basic: ItemAffixPower(
                    description: "Burn damage has a 20% chance to also Bleed, and vice versa. Burn and Bleed damage now Leech.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dot: DotTriggers(
                            burnProcsBleedChancePercent: 0.20,
                            bleedProcsBurnChancePercent: 0.20,
                            burnDamageLeech: true,
                            bleedDamageLeech: true
                        )
                    )
                ),
                astral: ItemAffixPower(
                    description: "Burn damage has a 20% chance to also Bleed, and vice versa. Burn and Bleed damage now Leech.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dot: DotTriggers(
                            burnProcsBleedChancePercent: 0.20,
                            bleedProcsBurnChancePercent: 0.20,
                            burnDamageLeech: true,
                            bleedDamageLeech: true
                        )
                    )
                )
            )),
            .catalog(id: "biting"),
            .catalog(id: "vampiric"),
            .catalog(id: "bloodstone"),
        ]
    )

    // MARK: - Rimeheart Locket (Sapphire Amulet)

    private static let rimeheartLocket = UniqueItemDefinition(
        id: "rimeheart_locket",
        displayName: "Rimeheart Locket",
        baseTypeID: "sapphire_amulet",
        affixes: [
            .bespoke(ItemAffixDefinition(
                id: "rimeheart",
                title: "Rimeheart",
                slot: .accessory,
                keywords: [.freeze, .block, .mana],
                weight: 0,
                basic: ItemAffixPower(
                    description: "Dealing Freeze damage grants that amount of Block. Gain Mana equal to your Block when you Freeze an enemy.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        block: BlockTriggers(freezeDamageGrantsBlock: true),
                        mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true)
                    )
                ),
                astral: ItemAffixPower(
                    description: "Dealing Freeze damage grants that amount of Block. Gain Mana equal to your Block when you Freeze an enemy.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        block: BlockTriggers(freezeDamageGrantsBlock: true),
                        mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true)
                    )
                )
            )),
            .catalog(id: "rime"),
            .catalog(id: "aetherward"),
            // Manabound pinned with Mana-only keywords so the locket stays within
            // the Sapphire affinity theme; the power matches the catalog astral.
            .bespoke(ItemAffixDefinition(
                id: "manabound_pinned",
                title: "Manabound",
                slot: .accessory,
                keywords: [.mana],
                weight: 0,
                basic: ItemAffixPower(
                    description: "Increase Maximum Mana by 8.",
                    modifiers: [.maximumMana(8)]
                ),
                astral: ItemAffixPower(
                    description: "Increase Maximum Mana by 8.",
                    modifiers: [.maximumMana(8)]
                )
            )),
        ]
    )
}
