import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let pixieTalents: [String: CombatantTalentEffect] = [
        // MARK: Pixie

        "pixie_cleanse_t1_1": CombatantTalentEffect(
            name: "Fae Mending",
            description: "Restore 2 Health to yourself when you Cleanse.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    cleanseSelfHeal: 2
                )
            )
        ),
        "pixie_cleanse_t1_2": CombatantTalentEffect(
            name: "Dispel Magic",
            description: "Cleanse effects also Purge 1 positive buff from the enemy.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseAlsoPurgesEnemyBuffs: 1
                )
            )
        ),
        "pixie_cleanse_t2_1": CombatantTalentEffect(
            name: "Fae Swiftness",
            description: "Cleansing an ally grants them +10% Dodge chance for 2 turns.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseDodgeChanceBonus: 0.10,
                    cleanseDodgeChanceBonusTurns: 2
                )
            )
        ),
        "pixie_cleanse_t2_2": CombatantTalentEffect(
            name: "Cleansing Ward",
            description: "Cleansing an ally also grants the party 2 Block.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleansePartyBlock: 2
                )
            )
        ),
        "pixie_cleanse_t3_1": CombatantTalentEffect(
            name: "Fae Ward",
            description: "Automatically block the first negative effect applied each turn.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    blockFirstDebuffPerTurn: true
                )
            )
        ),
        "pixie_cleanse_t3_2": CombatantTalentEffect(
            name: "Purifying Aura",
            description: "Debuffs on all party members expire twice as fast.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    partyDebuffDurationHalved: true
                )
            )
        ),
        "pixie_health_t1_1": CombatantTalentEffect(
            name: "Sprite Touch",
            description: "Regenerate 2 Health per turn for the first 3 turns of battle.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    healthRegenFirstTurnsAmount: 2,
                    healthRegenFirstTurnsDuration: 3
                )
            )
        ),
        "pixie_health_t1_2": CombatantTalentEffect(
            name: "Emergency Mend",
            description: "Healing allies below 30% Health restores double the amount.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    healingBelowHealthPercentThreshold: 0.30,
                    healingBelowHealthPercentMultiplier: 2
                )
            )
        ),
        "pixie_health_t2_1": CombatantTalentEffect(
            name: "Lingering Blessing",
            description: "Healing an ally applies a 3-turn heal over time of 1 Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    healOverTimeOnHealTurns: 3,
                    healOverTimeOnHealAmount: 1
                )
            )
        ),
        "pixie_health_t2_2": CombatantTalentEffect(
            name: "Protective Bloom",
            description: "Healing an ally also grants them 2 Block.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onHealGrantBlock: 2
                )
            )
        ),
        "pixie_health_t3_1": CombatantTalentEffect(
            name: "Vital Infusion",
            description: "Overhealing increases the target's Max Health by +1 this combat (up to +5).",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToMaxHealth: true,
                    overhealConvertsToMaxHealthCap: 5,
                    overhealConvertsToMaxHealthPerEvent: 1
                )
            )
        ),
        "pixie_health_t3_2": CombatantTalentEffect(
            name: "Barrier Blessing",
            description: "Excess healing is converted into Block for the healed ally.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToBlock: true
                )
            )
        ),
        "pixie_holy_t1_1": CombatantTalentEffect(
            name: "Dazzle",
            description: "Holy attacks reduce target damage by 2 on their next turn.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    holyDamageReduceTargetDamage: 2
                )
            )
        ),
        "pixie_holy_t1_2": CombatantTalentEffect(
            name: "Piercing Starlight",
            description: "Holy damage ignores enemy Block and cannot be Dodged.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    holyIgnoresBlockAndDodge: true
                )
            )
        ),
        "pixie_holy_t2_1": CombatantTalentEffect(
            name: "Radiant Barrier",
            description: "Dealing Holy damage grants 2 Block to the party.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onHolyDamagePartyBlock: 2
                )
            )
        ),
        "pixie_holy_t2_2": CombatantTalentEffect(
            name: "Stun Flare",
            description: "Holy attacks add 1 Burn and 1 Stun.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    holyAttackApplyBurnAndStunBuildup: 1
                )
            )
        ),
        "pixie_holy_t3_1": CombatantTalentEffect(
            name: "Supernal Glow",
            description: "All party basic attacks deal 2 additional Holy damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    partyBasicAttackHolyBonus: 2
                )
            )
        ),
        "pixie_holy_t3_2": CombatantTalentEffect(
            name: "Sunlight Spark",
            description: "Dealing Holy damage restores 2 Health to the lowest Health ally.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    holyDamageHealLowestAllyFlat: 2
                )
            )
        ),
    ]

    static let shieldScarabTalents: [String: CombatantTalentEffect] = [
        // MARK: Shield Scarab

        "shield_scarab_block_t1_1": CombatantTalentEffect(
            name: "Plated Hide",
            description: "Gain 2 Block each turn.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockPerTurn: 2
                )
            )
        ),
        "shield_scarab_block_t1_2": CombatantTalentEffect(
            name: "Hardened Chitin",
            description: "Take 2 less damage from non-Physical hits while you have Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    spellDamageTakenReductionWhileBlocked: 2
                )
            )
        ),
        "shield_scarab_block_t2_1": CombatantTalentEffect(
            name: "Enduring Shell",
            description: "Scarab's Block does not decay between rounds.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockDoesNotDecay: true
                )
            )
        ),
        "shield_scarab_block_t2_2": CombatantTalentEffect(
            name: "Bulwark Fortress",
            description: "While Scarab has Block, the Hero takes 50% less damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    companionBlockProtectsHeroPercent: 0.5
                )
            )
        ),
        "shield_scarab_block_t3_1": CombatantTalentEffect(
            name: "Spiked Shell",
            description: "Whenever you gain Block, deal half that much damage back to the attacker.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockGainThornsPercent: 0.5
                )
            )
        ),
        "shield_scarab_block_t3_2": CombatantTalentEffect(
            name: "Sun-Struck Shell",
            description: "When your Block is hit, deal 2 Holy damage to the attacker.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onBlockHitDealHoly: 2
                )
            )
        ),
        "shield_scarab_stun_t1_1": CombatantTalentEffect(
            name: "Sunder Shield",
            description: "Stunned enemies lose all their active Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    stunnedEnemyLoseAllBlock: true
                )
            )
        ),
        "shield_scarab_stun_t1_2": CombatantTalentEffect(
            name: "Heavy Slam",
            description: "Deal 4 additional Physical damage to Stunned enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetStunnedBonus: 4
                )
            )
        ),
        "shield_scarab_stun_t2_1": CombatantTalentEffect(
            name: "Prolonged Daze",
            description: "Stuns inflicted by Scarab last 1 additional turn.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunExtraActionSkips: 1
                )
            )
        ),
        "shield_scarab_stun_t2_2": CombatantTalentEffect(
            name: "Seismic Impact",
            description: "Enemies require 25% less Stun to be Stunned.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunThresholdReductionPercent: 0.25
                )
            )
        ),
        "shield_scarab_stun_t3_1": CombatantTalentEffect(
            name: "Quaking Carapace",
            description: "Add 3 Stun to the enemy and grant 5 Block to the party every 3 turns.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    everyNTurnsStunBuildupInterval: 3,
                    everyNTurnsStunBuildupAmount: 3,
                    everyNTurnsTeamBlockAmount: 5
                )
            )
        ),
        "shield_scarab_stun_t3_2": CombatantTalentEffect(
            name: "Solar Brand",
            description: "Stunning an enemy also inflicts 2 Burn on them.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onStunEnemyApplyBurn: 2
                )
            )
        ),
        "shield_scarab_holy_t1_1": CombatantTalentEffect(
            name: "Gilded Carapace",
            description: "Gain 2 Block whenever you deal Holy damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    holyDamageBlockFlat: 2
                )
            )
        ),
        "shield_scarab_holy_t1_2": CombatantTalentEffect(
            name: "Radiant Shell",
            description: "Enemies attacking the Scarab take 2 Holy damage.",
            triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(
                    onHitAttackerHoly: 2
                )
            )
        ),
        "shield_scarab_holy_t2_1": CombatantTalentEffect(
            name: "Sun Glyph",
            description: "Holy damage dealt by Scarab heals the Hero for 2 Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    holyDamageHealHeroFlat: 2
                )
            )
        ),
        "shield_scarab_holy_t2_2": CombatantTalentEffect(
            name: "Solar Ward",
            description: "Party deals 2 additional Holy damage while Scarab is at full Health.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    partyHolyDamageBonusWhileCompanionFullHealth: 2
                )
            )
        ),
        "shield_scarab_holy_t3_1": CombatantTalentEffect(
            name: "Dazzling Guard",
            description: "Blocking an attack reduces the attacker's accuracy by 25% for 2 turns.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onBlockReduceAttackerAccuracyPercent: 25,
                    onBlockReduceAttackerAccuracyTurns: 2
                )
            )
        ),
        "shield_scarab_holy_t3_2": CombatantTalentEffect(
            name: "Purifying Sun",
            description: "Holy damage deals double damage to Poisoned or Bleeding targets.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    holyDamageVsPoisonedOrBleedingMultiplier: 2
                )
            )
        ),
    ]

    static let foxTalents: [String: CombatantTalentEffect] = [
        // MARK: Fox

        "fox_gold_t1_1": CombatantTalentEffect(
            name: "Palmed Coin",
            description: "Gain 2 Gold when you Dodge.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeGoldFlat: 2
                )
            )
        ),
        "fox_gold_t1_2": CombatantTalentEffect(
            name: "Snatch",
            description: "Basic attacks steal 2 Gold from the enemy.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    basicAttackStealGold: 2
                )
            )
        ),
        "fox_gold_t2_1": CombatantTalentEffect(
            name: "Golden Opportunity",
            description: "Gaining Gold draws 1 card (once per turn).",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    onGainGoldDrawCardOncePerTurn: true
                )
            )
        ),
        "fox_gold_t2_2": CombatantTalentEffect(
            name: "Lucky Strike",
            description: "Critical hits grant 3 Gold.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    criticalGoldFlat: 3
                )
            )
        ),
        "fox_gold_t3_1": CombatantTalentEffect(
            name: "Master Thief",
            description: "When you Critically Hit, steal the enemy's Block and gain it yourself.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    critStealEnemyBlock: true
                )
            )
        ),
        "fox_gold_t3_2": CombatantTalentEffect(
            name: "Golden Recovery",
            description: "Gaining Gold restores 1 Health to the party.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    onGainGoldHealParty: 1
                )
            )
        ),
        "fox_dodge_t1_1": CombatantTalentEffect(
            name: "Feint Strike",
            description: "Dodging an attack increases the party's next card damage by 2.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgePartyNextCardDamageBonus: 2
                )
            )
        ),
        "fox_dodge_t1_2": CombatantTalentEffect(
            name: "Poisonous Dash",
            description: "Dodging an attack applies 2 Poison or 2 Bleed to the attacker.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeApplyPoisonOrBleed: 2
                )
            )
        ),
        "fox_dodge_t2_1": CombatantTalentEffect(
            name: "Shadow Shift",
            description: "50% chance to negate the first enemy attack of combat.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    negateFirstEnemyAttackChance: 0.5
                )
            )
        ),
        "fox_dodge_t2_2": CombatantTalentEffect(
            name: "Misdirection",
            description: "After Dodging, the enemy is off-balance: your next attack deals double damage.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    nextAttackDoubleAfterDodge: true
                )
            )
        ),
        "fox_dodge_t3_1": CombatantTalentEffect(
            name: "Decoy Swap",
            description: "50% chance when the Hero is attacked for Fox to swap places and Dodge for them.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    swapAndDodgeForHeroChance: 0.5
                )
            )
        ),
        "fox_dodge_t3_2": CombatantTalentEffect(
            name: "Stolen Breath",
            description: "Dodging restores 1 Mana to you and the Hero.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgePartyMana: 1
                )
            )
        ),
        "fox_stun_t1_1": CombatantTalentEffect(
            name: "Dazzling Tail",
            description: "Add 2 Stun to attackers when you Dodge their attack.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onDodgeAttackerStunBuildup: 2
                )
            )
        ),
        "fox_stun_t1_2": CombatantTalentEffect(
            name: "Confusing Feint",
            description: "Stunned enemies deal half damage on their next turn.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    stunnedEnemyNextTurnDamageMultiplier: 0.5
                )
            )
        ),
        "fox_stun_t2_1": CombatantTalentEffect(
            name: "Disorienting Strike",
            description: "Attacking a Stunned enemy grants 2 Gold and 2 Block.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onAttackStunnedEnemyGold: 2,
                    onAttackStunnedEnemyBlock: 2
                )
            )
        ),
        "fox_stun_t2_2": CombatantTalentEffect(
            name: "Chaos Manipulation",
            description: "Fox deals 50% additional damage to Stunned enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    stunnedDamageMultiplier: 1.50
                )
            )
        ),
        "fox_stun_t3_1": CombatantTalentEffect(
            name: "Affliction Burst",
            description: "When an enemy recovers from Stun, they suffer 2 Bleed, 2 Poison, and 2 Burn.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onEnemyStunRecoverApplyAfflictions: 2
                )
            )
        ),
        "fox_stun_t3_2": CombatantTalentEffect(
            name: "Confounding Loot",
            description: "Critical hits against Stunned enemies cause them to drop 3 Gold.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    criticalVsStunnedEnemyGold: 3
                )
            )
        ),
    ]
}
