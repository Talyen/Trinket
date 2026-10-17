import TrinketCore

extension UniqueCatalog {
    static let offhandDefinitions: [UniqueItemDefinition] = [
        unique(
            id: "laughing_guard",
            name: "Laughing Guard",
            base: "leather_buckler",
            keywords: [.block, .dodge],
            description: "Keep Block between turns\nDodging spends half your Block to deal that much Physical damage",
            triggers: CombatTraitTriggers {
                $0.retainAllBlockBetweenTurns = true
                $0.dodgeSpendsHalfBlockAsPhysical = true
            },
            supports: ["elusive", "untouchable", "defenders"],
            pinned: ["elusive", "untouchable"],
        ),
        unique(
            id: "the_knights_answer",
            name: "The Knight’s Answer",
            base: "kite_shield",
            keywords: [.block],
            description: "The first time each turn your Block absorbs attack damage, immediately use your Basic ability",
            triggers: CombatTraitTriggers { $0.blockedAttackBasicOncePerTurn = true },
            supports: ["concussive", "dazed", "defenders"],
        ),
        unique(
            id: "the_returning_flight",
            name: "The Returning Flight",
            base: "quiver",
            keywords: [.physical],
            description: "Your first Physical card each turn returns to your hand",
            triggers: CombatTraitTriggers { $0.recoverLastAttackCardEachTurn = true },
            supports: ["keen", "envenomed", "infected"],
        ),
        unique(
            id: "threefold_grace",
            name: "Threefold Grace",
            base: "spellbook",
            keywords: [.burn, .freeze, .holy],
            description: "Burn, Freeze, or Holy damage has a 10% chance to restore 1 Mana to the wearer",
            triggers: CombatTraitTriggers { $0.threefoldElementalDamageManaChancePercent = 0.10 },
            supports: ["smoldering", "glacial", "consecrated"],
        ),
    ]
}
