import TrinketCore

extension UniqueCatalog {
    static let offhandDefinitions: [UniqueItemDefinition] = [
        unique(
            id: "laughing_guard",
            name: "Laughing Guard",
            base: "leather_buckler",
            keywords: [.block, .dodge],
            description: "Keep Block between turns. Dodging spends half your Block to deal that much Physical damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(retainAllBlockBetweenTurns: true),
                dodge: DodgeTriggers(dodgeSpendsHalfBlockAsPhysical: true),
            ),
            supports: ["elusive", "untouchable", "defenders"],
            pinned: ["elusive", "untouchable"],
        ),
        unique(
            id: "the_knights_answer",
            name: "The Knight’s Answer",
            base: "kite_shield",
            keywords: [.block],
            description: "The first time each turn your Block absorbs attack damage, immediately use your Basic ability.",
            triggers: CombatTraitTriggers(block: BlockTriggers(blockedAttackBasicOncePerTurn: true)),
            supports: ["concussive", "dazed", "defenders"],
        ),
        unique(
            id: "the_returning_flight",
            name: "The Returning Flight",
            base: "quiver",
            keywords: [.physical],
            description: "Your first Physical card each turn returns to your hand.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(recoverLastAttackCardEachTurn: true)),
            supports: ["keen", "envenomed", "infected"],
        ),
        unique(
            id: "threefold_grace",
            name: "Threefold Grace",
            base: "spellbook",
            keywords: [.burn, .freeze, .holy],
            description: "Burn, Freeze, or Holy damage has a 10% chance to restore 1 Mana to the wearer.",
            triggers: CombatTraitTriggers(mana: ManaTriggers(threefoldElementalDamageManaChancePercent: 0.10)),
            supports: ["smoldering", "glacial", "consecrated"],
        ),
    ]
}
