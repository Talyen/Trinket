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
            description: "Holy damage causes Stun build-up and steals 1 Gold when it Stuns an enemy.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    holyStunBuildupPercent: 1,
                    holyTriggeredStunGoldFlat: 1,
                ),
            ),
            supports: ["stunning", "lucky", "absolving"],
        ),
    ] + meleeDefinitions + rangedDefinitions + offhandDefinitions + accessoryDefinitions

    private static let bloodfireSignet = unique(
        id: "bloodfire_signet",
        signatureID: "bloodfire",
        name: "Bloodfire Signet",
        base: "ruby_ring",
        keywords: [.burn, .bleed],
        description: "Dealing Burn damage has a 20% chance to deal 1 Bleed damage, and vice versa. Burn and Bleed damage gain Leech.",
        triggers: CombatTraitTriggers(
            dot: DotTriggers(
                burnProcsBleedChancePercent: 0.20,
                bleedProcsBurnChancePercent: 0.20,
                burnDamageLeech: true,
                bleedDamageLeech: true,
            ),
        ),
        supports: ["biting", "vampiric", "bloodstone"],
    )

    private static let rimeheartLocket = unique(
        id: "rimeheart_locket",
        signatureID: "rimeheart",
        name: "Rimeheart Locket",
        base: "sapphire_amulet",
        keywords: [.freeze, .block, .mana],
        description: "Dealing Freeze damage grants that amount of Block. Gain Mana equal to your Block when you Freeze an enemy.",
        triggers: CombatTraitTriggers(
            block: BlockTriggers(freezeDamageGrantsBlock: true),
            mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true),
        ),
        supports: ["rime", "aetherward", "manabound"],
        pinned: ["manabound"],
    )

    private static let saintfallPlate = unique(
        id: "saintfall_plate",
        signatureID: "saintfall",
        name: "Saintfall Plate",
        base: "plate_armor",
        keywords: [.block, .health, .holy, .stun],
        description: "The first time each round your Block is broken, deal 6 Holy and 6 Stun damage to the attacker, then restore 6 Health.",
        triggers: CombatTraitTriggers(
            block: BlockTriggers(blockBrokenSaintfallPower: 6),
        ),
        supports: ["bulwark", "sanctum", "vital"],
    )
}
