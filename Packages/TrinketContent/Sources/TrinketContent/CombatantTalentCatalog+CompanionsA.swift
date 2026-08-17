import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let bearTalents: [String: CombatantTalentEffect] = [
        // MARK: Bear

        "bear_block_t1_1": CombatantTalentEffect(
            name: "Thick Hide",
            description: "Reduces all damage taken by 2.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    passiveMitigationFlat: 2
                )
            )
        ),
        "bear_block_t1_2": CombatantTalentEffect(
            name: "Hibernation",
            description: "Restore 2 Health if you end your turn with Block.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    endTurnWithBlockHealFlat: 2
                )
            )
        ),
        "bear_block_t2_1": CombatantTalentEffect(
            name: "Grizzly Guard",
            description: "When Bear takes damage, grant 2 Block to the Hero.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onCompanionTakeDamageGrantHeroBlock: 2
                )
            )
        ),
        "bear_block_t2_2": CombatantTalentEffect(
            name: "Tough Pelt",
            description: "Bear takes 50% less Bleed damage.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    bleedResistance: 0.5
                )
            )
        ),
        "bear_block_t3_1": CombatantTalentEffect(
            name: "Ironhide",
            description: "Bear cannot take more than 12 damage in a single hit.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    maxDamagePerHitCap: 12
                )
            )
        ),
        "bear_block_t3_2": CombatantTalentEffect(
            name: "Vital Armor",
            description: "Gain 1 Max Health for every 5 Block gained in combat (up to +10 Max Health).",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockGainedMaxHealthEvery: 5
                )
            )
        ),
        "bear_physical_t1_1": CombatantTalentEffect(
            name: "Shield Breaker",
            description: "Physical attacks deal double damage to enemy Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    physicalBlockBreakMultiplier: 2
                )
            )
        ),
        "bear_physical_t1_2": CombatantTalentEffect(
            name: "Primal Rage",
            description: "Deal 1 additional damage for every 10 missing Health.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damagePerMissingHealthEvery: 10
                )
            )
        ),
        "bear_physical_t2_1": CombatantTalentEffect(
            name: "Cleaving Claws",
            description: "Physical attacks deal 2 additional damage.",
            modifiers: [.damageDealt(.physical, 2)]
        ),
        "bear_physical_t2_2": CombatantTalentEffect(
            name: "Heavy Impact",
            description: "Physical attacks ignore half of enemy Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    physicalBlockIgnorePercent: 0.5
                )
            )
        ),
        "bear_physical_t3_1": CombatantTalentEffect(
            name: "Enrage",
            description: "While Bear is below half Health, party attacks deal 3 additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    partyAllStatsBonusBelowHealthThreshold: 0.5,
                    partyAllStatsBonusBelowHealthAmount: 3
                )
            )
        ),
        "bear_physical_t3_2": CombatantTalentEffect(
            name: "Maul",
            description: "Physical attacks apply 1 Bleed and 1 Stun.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    physicalAttackApplyBleedAndStun: 1
                )
            )
        ),
        "bear_stun_t1_1": CombatantTalentEffect(
            name: "Ground Slam",
            description: "Physical attacks add 1 Stun.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    physicalAttackFlatStunBuildup: 1
                )
            )
        ),
        "bear_stun_t1_2": CombatantTalentEffect(
            name: "Dazing Swipe",
            description: "Attacks have a 25% chance to delay the enemy's turn.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    attackDelayEnemyTurnChancePercent: 0.25
                )
            )
        ),
        "bear_stun_t2_1": CombatantTalentEffect(
            name: "Shockwave",
            description: "Stunning an enemy deals 3 Physical damage to them.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    stunDealPhysicalFlat: 3
                )
            )
        ),
        "bear_stun_t2_2": CombatantTalentEffect(
            name: "Deep Stun",
            description: "Stun lasts 1 additional turn.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunExtraActionSkips: 1
                )
            )
        ),
        "bear_stun_t3_1": CombatantTalentEffect(
            name: "Exposed Prey",
            description: "Stunned enemies take 50% additional damage from Hero cards.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    heroDamageVsStunnedMultiplier: 1.5
                )
            )
        ),
        "bear_stun_t3_2": CombatantTalentEffect(
            name: "Seismic Roar",
            description: "The first time Bear drops below half Health each battle, Stun the enemy.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentStunAllEnemies: true,
                    onceBelowHealthPercentThreshold: 0.5
                )
            )
        ),
    ]

    static let frostWhelpTalents: [String: CombatantTalentEffect] = [
        // MARK: Frost Whelp

        "frost_whelp_freeze_t1_1": CombatantTalentEffect(
            name: "Permafrost",
            description: "Increase Freeze damage dealt by 2.",
            modifiers: [.damageDealt(.freeze, 2)]
        ),
        "frost_whelp_freeze_t1_2": CombatantTalentEffect(
            name: "Chilling Scales",
            description: "When attacked, add 2 Freeze to the attacker.",
            triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(
                    onHitAttackerFreezeBuildup: 2
                )
            )
        ),
        "frost_whelp_freeze_t2_1": CombatantTalentEffect(
            name: "Glacial Grip",
            description: "Freeze meter on enemies does not fade.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    freezeBuildupDoesNotDecay: true
                )
            )
        ),
        "frost_whelp_freeze_t2_2": CombatantTalentEffect(
            name: "Frost Siphon",
            description: "Attacking a Frozen enemy grants 1 Mana.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onAttackFrozenEnemyGainMana: 1
                )
            )
        ),
        "frost_whelp_freeze_t3_1": CombatantTalentEffect(
            name: "Shatter Frost",
            description: "Frozen enemies take 25% additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsFrozenMultiplier: 1.25
                )
            )
        ),
        "frost_whelp_freeze_t3_2": CombatantTalentEffect(
            name: "Freezing Gale",
            description: "Apply 2 Freeze to the enemy every 3 turns.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    everyNTurnsFreezeAllEnemiesInterval: 3,
                    everyNTurnsFreezeAllEnemiesAmount: 2
                )
            )
        ),
        "frost_whelp_mana_t1_1": CombatantTalentEffect(
            name: "Dragon Spark",
            description: "Start each battle with 2 extra Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    startBattleBonusMana: 2
                )
            )
        ),
        "frost_whelp_mana_t1_2": CombatantTalentEffect(
            name: "Arcane Breath",
            description: "When you spend 3 Mana to empower a card, add 3 damage per Mana spent.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaDamageBonusPerMana: 3
                )
            )
        ),
        "frost_whelp_mana_t2_1": CombatantTalentEffect(
            name: "Mana Absorption",
            description: "Gain 2 Block whenever the Hero spends Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    onHeroSpendManaGainBlock: 2
                )
            )
        ),
        "frost_whelp_mana_t2_2": CombatantTalentEffect(
            name: "Aetherial Armor",
            description: "Gain 1 damage reduction for every 2 unspent Mana.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    damageReductionPerUnspentManaEvery: 2
                )
            )
        ),
        "frost_whelp_mana_t3_1": CombatantTalentEffect(
            name: "Mana Flow",
            description: "Spending Mana has a 25% chance to refund the Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaRefundChancePercent: 0.25
                )
            )
        ),
        "frost_whelp_mana_t3_2": CombatantTalentEffect(
            name: "Spell Channeling",
            description: "When you spend Mana to empower the Whelp's cards, it costs 2 Mana instead of 3.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    empowermentCostReduction: 1
                )
            )
        ),
        "frost_whelp_dodge_t1_1": CombatantTalentEffect(
            name: "High Altitude",
            description: "While above half Health, enemy attacks target the Hero instead of the Whelp.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    untargetableAboveHealthPercent: 0.50
                )
            )
        ),
        "frost_whelp_dodge_t1_2": CombatantTalentEffect(
            name: "Tailwind",
            description: "Dodging an attack draws 1 card for the Hero.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeDrawCardForHero: 1
                )
            )
        ),
        "frost_whelp_dodge_t2_1": CombatantTalentEffect(
            name: "Flyby Strike",
            description: "After Dodging, your next attack deals double damage.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    nextAttackDoubleAfterDodge: true
                )
            )
        ),
        "frost_whelp_dodge_t2_2": CombatantTalentEffect(
            name: "Wing Buffet",
            description: "Dodging an attack delays the attacker's next turn.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeDelayAttackerTurn: true
                )
            )
        ),
        "frost_whelp_dodge_t3_1": CombatantTalentEffect(
            name: "Aerial Cover",
            description: "Dodging an attack grants the Hero 3 Block.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeGrantHeroBlock: 3
                )
            )
        ),
        "frost_whelp_dodge_t3_2": CombatantTalentEffect(
            name: "Tempest Wing",
            description: "Each Dodge restores 1 Mana to you and the Hero.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgePartyMana: 1
                )
            )
        ),
    ]
}
