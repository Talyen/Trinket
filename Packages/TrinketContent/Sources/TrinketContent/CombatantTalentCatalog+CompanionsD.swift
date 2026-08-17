import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let goldenRetrieverTalents: [String: CombatantTalentEffect] = [
        // MARK: Golden Retriever

        "golden_retriever_gold_t1_1": CombatantTalentEffect(
            name: "Bounty",
            description: "Gain 3 Gold when you defeat an enemy.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    defeatEnemyGoldFlat: 3
                )
            )
        ),
        "golden_retriever_gold_t1_2": CombatantTalentEffect(
            name: "Dig for Treasure",
            description: "Gain 2 Gold every 3 turns.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    goldEveryNTurnsInterval: 3,
                    goldEveryNTurnsAmount: 2
                )
            )
        ),
        "golden_retriever_gold_t2_1": CombatantTalentEffect(
            name: "Haggler",
            description: "All Gold you gain in combat is increased by 15%.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    partyGoldGainedPercent: 0.15
                )
            )
        ),
        "golden_retriever_gold_t2_2": CombatantTalentEffect(
            name: "Golden Guard",
            description: "Gain 1 Block for every 2 Gold earned in combat.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockPerGoldEarnedEvery: 2
                )
            )
        ),
        "golden_retriever_gold_t3_1": CombatantTalentEffect(
            name: "Fetch!",
            description: "Gain 2 Gold when an enemy plays an ability.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    onEnemyAbilityGold: 2
                )
            )
        ),
        "golden_retriever_gold_t3_2": CombatantTalentEffect(
            name: "Treasure Hoard",
            description: "While you have 50 or more Gold, the party gains +10% Critical Hit chance.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    partyCritChanceWhileGoldAbove: 50,
                    partyCritChanceWhileGoldAboveBonus: 0.10
                )
            )
        ),
        "golden_retriever_block_t1_1": CombatantTalentEffect(
            name: "Guardian",
            description: "Absorb 2 damage whenever the Hero is attacked.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    absorbHeroDamageFlat: 2
                )
            )
        ),
        "golden_retriever_block_t1_2": CombatantTalentEffect(
            name: "Watchful Eye",
            description: "Start each battle with 3 Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    startBattleBlock: 3
                )
            )
        ),
        "golden_retriever_block_t2_1": CombatantTalentEffect(
            name: "Shield Bond",
            description: "Whenever Retriever gains Block, the Hero gains equal Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    companionBlockSharesToHeroPercent: 1
                )
            )
        ),
        "golden_retriever_block_t2_2": CombatantTalentEffect(
            name: "Warning Bark",
            description: "Negate the first enemy attack of each combat.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    negateFirstEnemyAttack: true
                )
            )
        ),
        "golden_retriever_block_t3_1": CombatantTalentEffect(
            name: "Sacrificial Guard",
            description: "When the Hero would die, the Retriever takes that hit instead and gains 10 Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    companionFatalDamageRedirectBlock: 10
                )
            )
        ),
        "golden_retriever_block_t3_2": CombatantTalentEffect(
            name: "Steadfast",
            description: "While holding Block, Stun and Freeze on the Retriever is halved, and Burn damage taken is halved.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    blockedControlBurnResistance: 0.5
                )
            )
        ),
        "golden_retriever_health_t1_1": CombatantTalentEffect(
            name: "Cheer Up",
            description: "Restore 3 Health to the lowest Health party member at end of turn.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    endOfTurnHealLowestAlly: 3
                )
            )
        ),
        "golden_retriever_health_t1_2": CombatantTalentEffect(
            name: "Playful Energy",
            description: "Playing 3 cards in a turn heals the party for 2 Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    cardsPlayedHealPartyThreshold: 3,
                    cardsPlayedHealPartyAmount: 2
                )
            )
        ),
        "golden_retriever_health_t2_1": CombatantTalentEffect(
            name: "Campfire Comfort",
            description: "At the end of each round, restore 2 Health to each party member.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    partyRegenPerRound: 2
                )
            )
        ),
        "golden_retriever_health_t2_2": CombatantTalentEffect(
            name: "Man's Best Friend",
            description: "Hero gains +15% Critical Hit chance while Retriever is alive.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    heroCritChanceWhileCompanionAlive: 0.15
                )
            )
        ),
        "golden_retriever_health_t3_1": CombatantTalentEffect(
            name: "Inspirational Vigor",
            description: "While Retriever is below half Health, party attacks deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    partyAllStatsBonusBelowHealthThreshold: 0.5,
                    partyAllStatsBonusBelowHealthAmount: 2
                )
            )
        ),
        "golden_retriever_health_t3_2": CombatantTalentEffect(
            name: "Protective Lick",
            description: "When an ally takes damage, heal them for 1 Health.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    onAllyDamageHeal: 1
                )
            )
        ),
    ]

    static let libraryOwlTalents: [String: CombatantTalentEffect] = [
        // MARK: Library Owl

        "library_owl_holy_t1_1": CombatantTalentEffect(
            name: "Revealed Flaw",
            description: "Holy attacks make the next hit deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    holyDamageNextHitBonus: 2
                )
            )
        ),
        "library_owl_holy_t1_2": CombatantTalentEffect(
            name: "Scholarly Smite",
            description: "When the Hero uses a Holy ability, Owl deals 2 Holy damage to the target.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    onHeroHolyAbilityCompanionHolyDamage: 2
                )
            )
        ),
        "library_owl_holy_t2_1": CombatantTalentEffect(
            name: "Blinding Light",
            description: "When you hit with Holy damage, the target misses their next attack.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    holyDamageTargetMissNextAttack: true
                )
            )
        ),
        "library_owl_holy_t2_2": CombatantTalentEffect(
            name: "Radiant Wisdom",
            description: "Restore 1 Mana whenever you deal Holy damage.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    onHolyDamageRestoreMana: 1
                )
            )
        ),
        "library_owl_holy_t3_1": CombatantTalentEffect(
            name: "Bane of Evil",
            description: "Holy damage deals double damage to undead and corrupted enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    holyDamageVsUndeadOrCorruptedMultiplier: 2
                )
            )
        ),
        "library_owl_holy_t3_2": CombatantTalentEffect(
            name: "Purifying Light",
            description: "Holy attacks remove all positive buffs from the target.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    holyDamagePurgeAll: true
                )
            )
        ),
        "library_owl_cleanse_t1_1": CombatantTalentEffect(
            name: "Purifying Wisdom",
            description: "Draw a card when you Cleanse.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseBonusDraw: 1
                )
            )
        ),
        "library_owl_cleanse_t1_2": CombatantTalentEffect(
            name: "Healing Hymn",
            description: "Cleansing an ally also heals them for 2 Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    cleanseBonusHeal: 2
                )
            )
        ),
        "library_owl_cleanse_t2_1": CombatantTalentEffect(
            name: "Spellbreak Shield",
            description: "Cleansing a negative effect grants 2 Block per effect removed.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseBlockPerStack: 2
                )
            )
        ),
        "library_owl_cleanse_t2_2": CombatantTalentEffect(
            name: "Mass Cleanse",
            description: "Cleanse also removes negative effects from the rest of the party.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseAffectsBothHeroAndCompanion: true
                )
            )
        ),
        "library_owl_cleanse_t3_1": CombatantTalentEffect(
            name: "Reflective Ward",
            description: "Cleansing a negative effect reflects it onto the enemy who applied it.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseReflectDebuffToEnemy: true
                )
            )
        ),
        "library_owl_cleanse_t3_2": CombatantTalentEffect(
            name: "Sanctified Scroll",
            description: "Cleanse 1 negative effect from the party automatically each round.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    autoCleanseTeamPerTurn: 1
                )
            )
        ),
        "library_owl_health_t1_1": CombatantTalentEffect(
            name: "Safe Perch",
            description: "Regenerate 2 Health per turn while above half Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    healthRegenAboveHalfHealth: 2
                )
            )
        ),
        "library_owl_health_t1_2": CombatantTalentEffect(
            name: "Warded Roost",
            description: "Healing an ally also grants them 2 Block.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onHealGrantBlock: 2
                )
            )
        ),
        "library_owl_health_t2_1": CombatantTalentEffect(
            name: "Efficient Care",
            description: "When you spend 3 Mana to empower a heal, it costs 2 Mana instead of 3.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    healingEmpowermentCostReduction: 1
                )
            )
        ),
        "library_owl_health_t2_2": CombatantTalentEffect(
            name: "Aether Shield",
            description: "Overhealing converts into Block, absorbing up to 8 damage.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealShieldCap: 8
                )
            )
        ),
        "library_owl_health_t3_1": CombatantTalentEffect(
            name: "Guardian Archive",
            description: "When a party member hits Death's Door, heal them for 10 Health and cleanse all negative effects.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onAllyDeathsDoorHealAndCleanse: 10
                )
            )
        ),
        "library_owl_health_t3_2": CombatantTalentEffect(
            name: "Font of Magic",
            description: "Healing an ally restores 1 Mana to the caster.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onHealRestoreCasterMana: 1
                )
            )
        ),
    ]
}
