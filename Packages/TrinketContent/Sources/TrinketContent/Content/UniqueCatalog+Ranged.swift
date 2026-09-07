import TrinketCore

extension UniqueCatalog {
    static let rangedDefinitions: [UniqueItemDefinition] = [
        unique(
            id: "huntsmasters_call",
            name: "Huntsmaster’s Call",
            base: "longbow",
            keywords: [.physical],
            description: "Your first Critical Hit each turn makes your Companion use its Basic Ability.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(firstCriticalHitCompanionBasicPerTurn: true)),
            supports: ["keen", "serrated", "envenomed"],
        ),
        unique(
            id: "wrenflight",
            name: "Wrenflight",
            base: "shortbow",
            keywords: [.physical],
            description: "Playing your second card each turn draws a card and grants 10% Dodge until your next turn.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(secondCardDrawAndDodgePercent: 0.1)),
            supports: ["keen", "infected", "contagion"],
        ),
        unique(
            id: "the_returning_gale",
            name: "The Returning Gale",
            base: "recurve_bow",
            keywords: [.physical],
            description: "The third card you play each turn returns to your hand after resolving.",
            triggers: CombatTraitTriggers(attack: AttackTriggers(thirdCardReturnsToHand: true)),
            supports: ["keen", "serrated", "lingering"],
        ),
        unique(
            id: "the_final_spark",
            name: "The Final Spark",
            base: "wand",
            keywords: [.burn, .freeze, .mana],
            description: "Once per turn, spending your last Mana to empower a Burn or Freeze card repeats its damage.",
            triggers: CombatTraitTriggers(mana: ManaTriggers(lastManaEmpowermentRepeatsDamage: true)),
            supports: ["smoldering", "glacial", "channeled"],
        ),
    ]
}
