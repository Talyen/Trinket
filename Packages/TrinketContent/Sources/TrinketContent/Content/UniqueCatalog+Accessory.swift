import TrinketCore

extension UniqueCatalog {
    static let accessoryDefinitions: [UniqueItemDefinition] = [
        unique(
            id: "bloodember_pendant",
            name: "Bloodember Pendant",
            base: "ruby_amulet",
            keywords: [.burn, .bleed],
            description: "Burn and Bleed share their damage bonuses.",
            triggers: CombatTraitTriggers(dot: DotTriggers(burnAndBleedShareDamageBonuses: true)),
            supports: ["smoldering", "serrated", "vampiric"],
            pinned: ["smoldering", "serrated"],
        ),
        unique(
            id: "winters_credit",
            name: "Winter’s Credit",
            base: "sapphire_ring",
            keywords: [.freeze, .block, .mana],
            description: "When empowering a Freeze card, spend 3 Block per missing Mana.",
            triggers: CombatTraitTriggers(mana: ManaTriggers(freezeEmpowermentBlockPerMana: 3)),
            supports: ["rime", "aetherward", "manabound"],
            pinned: ["manabound"],
        ),
        unique(
            id: "serpents_eye",
            name: "Serpent’s Eye",
            base: "emerald_ring",
            keywords: [.poison],
            description: "Your attacks against Poisoned enemies ignore Block.",
            triggers: CombatTraitTriggers(damage: DamageTriggers(attacksIgnoreBlockWhileTargetPoisoned: true)),
            supports: ["envenomed", "contagion", "hale"],
            pinned: ["envenomed", "contagion"],
        ),
        unique(
            id: "wildhearts_favor",
            name: "Wildheart’s Favor",
            base: "emerald_amulet",
            keywords: [.poison],
            description: "Dodging draws a Poison card and guarantees your next Poison card’s damage Critically Hits.",
            triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeDrawPoisonAndReadyCritical: true)),
            supports: ["envenomed", "hale", "beastbond"],
            pinned: ["envenomed"],
        ),
        unique(
            id: "the_golden_crucible",
            name: "The Golden Crucible",
            base: "topaz_amulet",
            keywords: [.gold, .holy],
            description: "Gold gained in combat adds equal damage to your next Holy hit.",
            triggers: CombatTraitTriggers(gold: GoldTriggers(goldGainedNextHolyDamage: true)),
            supports: ["lucky", "gilded", "absolving"],
        ),
    ]
}
