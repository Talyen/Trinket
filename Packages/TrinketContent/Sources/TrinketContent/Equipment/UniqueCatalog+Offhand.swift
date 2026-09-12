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
            description: "At turn start, recover your last attack card from the previous turn, if it remains in your deck.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(recoverLastAttackCardEachTurn: true)),
            supports: ["keen", "envenomed", "infected"],
        ),
        unique(
            id: "threefold_grace",
            name: "Threefold Grace",
            base: "spellbook",
            keywords: [.burn, .freeze, .holy],
            description: "Your first Burn, Freeze, and Holy card each turn each draw a card.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(firstElementCardsDraw: true)),
            supports: ["smoldering", "glacial", "consecrated"],
        ),
    ]
}
