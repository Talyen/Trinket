import Foundation
import TrinketCore

enum UniqueCatalog {
    static let definitions: [UniqueItemDefinition] = [
        unique(
            id: "wardbreaker",
            name: "Wardbreaker",
            base: "flail",
            keywords: [.stun, .holy],
            description: "Purge all beneficial status effects when you Stun an enemy. Deal 2 Holy damage for each effect removed.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    stunPurgeDealHolyPerEffect: 2,
                ),
            ),
            supports: ["dazed", "concussive", "sentinel"],
        ),
        unique(
            id: "dance_of_blades",
            name: "Dance of Blades",
            base: "leather_armor",
            keywords: [.dodge],
            description: "When you Dodge, immediately draw and play a card. If it's a Critical Hit, repeat this effect.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeDrawAndPlayCardChainOnCrit: true),
            ),
            supports: ["riposte", "untouchable", "sidestep"],
        ),
        bloodfireSignet,
        rimeheartLocket,
        unique(
            id: "blackfletch",
            name: "Blackfletch",
            base: "crossbow",
            keywords: [.physical, .bleed, .poison],
            description: "Critical Hits detonate and consume all remaining Bleed and Poison damage.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(criticalDetonateBleedAndPoison: true),
            ),
            supports: ["infected", "lingering", "contagion"],
        ),
        unique(
            id: "twin_casting",
            name: "Twin Casting",
            base: "staff",
            keywords: [.burn, .freeze, .mana],
            description: "After you spend Mana to empower a Burn card, draw a Freeze card, and vice versa.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(empoweredElementDrawOpposite: true),
            ),
            supports: ["smoldering", "glacial", "channeled"],
        ),
        saintfallPlate,
        unique(
            id: "golden_verdict",
            name: "Golden Verdict",
            base: "topaz_ring",
            keywords: [.holy, .gold, .stun],
            description: "Holy damage builds an equal amount of Stun. When this Stuns an enemy, gain 1 Gold.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    holyStunBuildupPercent: 1,
                    holyTriggeredStunGoldFlat: 1,
                ),
            ),
            supports: ["stunning", "lucky", "absolving"],
        ),
    ] + meleeDefinitions + rangedDefinitions + offhandDefinitions + accessoryDefinitions

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
                    description: "Dealing Burn damage has a 20% chance to deal 1 Bleed damage, and vice versa. Burn and Bleed damage gain Leech.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dot: DotTriggers(
                            burnProcsBleedChancePercent: 0.20,
                            bleedProcsBurnChancePercent: 0.20,
                            burnDamageLeech: true,
                            bleedDamageLeech: true,
                        ),
                    ),
                ),
                astral: ItemAffixPower(
                    description: "Dealing Burn damage has a 20% chance to deal 1 Bleed damage, and vice versa. Burn and Bleed damage gain Leech.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        dot: DotTriggers(
                            burnProcsBleedChancePercent: 0.20,
                            bleedProcsBurnChancePercent: 0.20,
                            burnDamageLeech: true,
                            bleedDamageLeech: true,
                        ),
                    ),
                ),
            )),
            .catalog(id: "biting"),
            .catalog(id: "vampiric"),
            .catalog(id: "bloodstone"),
        ],
    )

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
                        mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true),
                    ),
                ),
                astral: ItemAffixPower(
                    description: "Dealing Freeze damage grants that amount of Block. Gain Mana equal to your Block when you Freeze an enemy.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        block: BlockTriggers(freezeDamageGrantsBlock: true),
                        mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true),
                    ),
                ),
            )),
            .catalog(id: "rime"),
            .catalog(id: "aetherward"),
            .bespoke(ItemAffixDefinition(
                id: "manabound_pinned",
                title: "Manabound",
                slot: .accessory,
                keywords: [.mana],
                weight: 0,
                basic: ItemAffixPower(
                    description: "Increase Maximum Mana by 8.",
                    modifiers: [.maximumMana(8)],
                ),
                astral: ItemAffixPower(
                    description: "Increase Maximum Mana by 8.",
                    modifiers: [.maximumMana(8)],
                ),
            )),
        ],
    )

    private static let saintfallPlate = UniqueItemDefinition(
        id: "saintfall_plate",
        displayName: "Saintfall Plate",
        baseTypeID: "plate_armor",
        affixes: [
            .bespoke(ItemAffixDefinition(
                id: "saintfall",
                title: "Saintfall",
                slot: .armor,
                keywords: [.block, .health, .holy, .stun],
                weight: 0,
                basic: ItemAffixPower(
                    description: "The first time each round your Block is broken, deal 6 Holy and 6 Stun damage to the attacker, then restore 6 Health.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        block: BlockTriggers(blockBrokenSaintfallPower: 6),
                    ),
                ),
                astral: ItemAffixPower(
                    description: "The first time each round your Block is broken, deal 6 Holy and 6 Stun damage to the attacker, then restore 6 Health.",
                    modifiers: [],
                    triggers: CombatTraitTriggers(
                        block: BlockTriggers(blockBrokenSaintfallPower: 6),
                    ),
                ),
            )),
            .catalog(id: "bulwark"),
            .catalog(id: "sanctum"),
            .catalog(id: "vital"),
        ],
    )
}
