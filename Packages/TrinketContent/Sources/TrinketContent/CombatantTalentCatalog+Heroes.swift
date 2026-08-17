import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let knightTalents: [String: CombatantTalentEffect] = [
        // MARK: Knight

        "knight_block_t1_1": CombatantTalentEffect(
            name: "Bastion Stance",
            description: "Gain 2 Block at the start of each round.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockPerTurn: 2
                )
            )
        ),
        "knight_block_t1_2": CombatantTalentEffect(
            name: "Spiked Barricade",
            description: "Whenever you gain Block, deal half that much damage back to the attacker.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockGainThornsPercent: 0.5
                )
            )
        ),
        "knight_block_t2_1": CombatantTalentEffect(
            name: "Intercede",
            description: "Your Block also absorbs damage dealt to your Companion.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockAbsorbsCompanionDamage: true
                )
            )
        ),
        "knight_block_t2_2": CombatantTalentEffect(
            name: "Shield Bash",
            description: "While you have Block, attacks deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    shieldDamageBonusWhileBlocked: 2
                )
            )
        ),
        "knight_block_t3_1": CombatantTalentEffect(
            name: "Shield Shatter",
            description: "Breaking an enemy's Block deals 6 Physical damage to them.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onEnemyBlockBrokenDealPhysical: 6
                )
            )
        ),
        "knight_block_t3_2": CombatantTalentEffect(
            name: "Unbreakable",
            description: "Your Block retains 75% at the end of each round (up to 30 max). Damage that gets through Block is reduced by 15%.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockDoesNotDecay: true,
                    postBlockOverflowDamageMultiplier: 0.85
                )
            )
        ),
        "knight_holy_t1_1": CombatantTalentEffect(
            name: "Oathbound",
            description: "Gain 2 Block when you deal Stun or Holy damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    holyDamageBlockFlat: 2,
                    stunDamageBlockFlat: 2
                )
            )
        ),
        "knight_holy_t1_2": CombatantTalentEffect(
            name: "Pure Radiance",
            description: "Holy damage deals 50% bonus damage against enemy Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    sunderingBlockMultiplier: 0.5
                )
            )
        ),
        "knight_holy_t2_1": CombatantTalentEffect(
            name: "Holy Infusion",
            description: "Dealing Holy damage adds 3 Holy damage to your next attack.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    holyDamageNextAttackHolyBonus: 3
                )
            )
        ),
        "knight_holy_t2_2": CombatantTalentEffect(
            name: "Consecration",
            description: "Cleanse 1 negative effect from yourself when you deal Holy damage.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    holyDamageCleanseCount: 1
                )
            )
        ),
        "knight_holy_t3_1": CombatantTalentEffect(
            name: "Smite the Wicked",
            description: "Holy attacks deal double damage to Stunned or Burning enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    holyDamageVsStunnedOrBurningMultiplier: 2
                )
            )
        ),
        "knight_holy_t3_2": CombatantTalentEffect(
            name: "Divine Blessing",
            description: "Dealing Holy damage restores 4 Health to the lowest Health party member.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    holyDamageHealLowestAllyFlat: 4
                )
            )
        ),
        "knight_stun_t1_1": CombatantTalentEffect(
            name: "Heavy Flail",
            description: "Attacks against Stunned enemies deal 3 additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetStunnedBonus: 3
                )
            )
        ),
        "knight_stun_t1_2": CombatantTalentEffect(
            name: "Concussive Blow",
            description: "Stunned enemies deal half damage on their next turn.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    stunnedEnemyNextTurnDamageMultiplier: 0.5
                )
            )
        ),
        "knight_stun_t2_1": CombatantTalentEffect(
            name: "Skullcracker",
            description: "Critical hits add 2 Stun.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    criticalApplyStunBuildup: 2
                )
            )
        ),
        "knight_stun_t2_2": CombatantTalentEffect(
            name: "Second Wind",
            description: "Draw a card when an enemy recovers from Stun.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onEnemyStunRecoverDrawCard: 1
                )
            )
        ),
        "knight_stun_t3_1": CombatantTalentEffect(
            name: "Relentless Hold",
            description: "Stun lasts 1 additional turn on the enemy.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunExtraActionSkips: 1
                )
            )
        ),
        "knight_stun_t3_2": CombatantTalentEffect(
            name: "Crusader's Mark",
            description: "Stunned enemies take 5 additional damage from Holy attacks.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    holyDamageVsStunnedBonus: 5
                )
            )
        ),
    ]

    static let rogueTalents: [String: CombatantTalentEffect] = [
        // MARK: Rogue

        "rogue_poison_t1_1": CombatantTalentEffect(
            name: "Toxic Coating",
            description: "Critical hits apply 2 Poison.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    criticalApplyPoison: 2
                )
            )
        ),
        "rogue_poison_t1_2": CombatantTalentEffect(
            name: "Lingering Toxin",
            description: "Poison on enemies fades 25% slower each round.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDecaySlowPercent: 0.25
                )
            )
        ),
        "rogue_poison_t2_1": CombatantTalentEffect(
            name: "Noxious Reaction",
            description: "Bleed damage also deals Poison's current damage immediately.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBleedDamagePoisonTick: 1
                )
            )
        ),
        "rogue_poison_t2_2": CombatantTalentEffect(
            name: "Blinding Fumes",
            description: "Attacks from Poisoned enemies deal 20% less damage.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    poisonedEnemyAccuracyPenaltyPercent: 0.20
                )
            )
        ),
        "rogue_poison_t3_1": CombatantTalentEffect(
            name: "Contagion",
            description: "Poison damage has a 25% chance to grow instead of fading.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDecayIncreaseChance: 0.25
                )
            )
        ),
        "rogue_poison_t3_2": CombatantTalentEffect(
            name: "Deadly Dose",
            description: "Poisoned enemies take 25% additional damage from all sources.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsPoisonedMultiplier: 1.25
                )
            )
        ),
        "rogue_bleed_t1_1": CombatantTalentEffect(
            name: "Serrated Blades",
            description: "Applying Bleed to a Bleeding target extends its duration by 1 turn.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBleedAppliedToBleedingExtendTurns: 1
                )
            )
        ),
        "rogue_bleed_t1_2": CombatantTalentEffect(
            name: "Deep Wounds",
            description: "Bleed ignores the enemy's damage reduction.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    bleedsIgnoreMitigation: true
                )
            )
        ),
        "rogue_bleed_t2_1": CombatantTalentEffect(
            name: "Taste for Blood",
            description: "When Bleed deals damage, your next basic attack is a guaranteed Critical Hit.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onBleedDamageNextBasicGuaranteedCrit: true
                )
            )
        ),
        "rogue_bleed_t2_2": CombatantTalentEffect(
            name: "Blood Money",
            description: "When Bleed deals damage, gain 2 Gold.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    bleedDamageGoldFlat: 2
                )
            )
        ),
        "rogue_bleed_t3_1": CombatantTalentEffect(
            name: "Exsanguinate",
            description: "Critical hits on Bleeding targets detonate and consume all remaining Bleed damage at once.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    criticalOnBleedingDetonateBleed: true
                )
            )
        ),
        "rogue_bleed_t3_2": CombatantTalentEffect(
            name: "Scent of Blood",
            description: "Deal 3 additional damage to Bleeding enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBleedingBonus: 3
                )
            )
        ),
        "rogue_gold_t1_1": CombatantTalentEffect(
            name: "Light Fingers",
            description: "Gain 2 Gold when you Critically Hit.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    criticalGoldFlat: 2
                )
            )
        ),
        "rogue_gold_t1_2": CombatantTalentEffect(
            name: "Deep Pockets",
            description: "Start each battle with 15 bonus Gold.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    startBattleBonusGold: 15
                )
            )
        ),
        "rogue_gold_t2_1": CombatantTalentEffect(
            name: "Cutpurse Cut",
            description: "Attacks steal 2 Gold from the target.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onAttackStealGold: 2
                )
            )
        ),
        "rogue_gold_t2_2": CombatantTalentEffect(
            name: "Gold Reserves",
            description: "Deal 1 additional damage for every 10 Gold carried (up to +5 bonus damage).",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    goldReservesDamageEvery: 10
                )
            )
        ),
        "rogue_gold_t3_1": CombatantTalentEffect(
            name: "Bounty Hunter",
            description: "Defeating an enemy with a Critical Hit grants 10 bonus Gold.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    critOnDefeatGold: 10
                )
            )
        ),
        "rogue_gold_t3_2": CombatantTalentEffect(
            name: "Golden Touch",
            description: "Gaining Gold doubles the next Poison, Bleed, or Burn you apply.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    onGainGoldDoubleStatusEffectsNextCard: true
                )
            )
        ),
    ]

    static let wizardTalents: [String: CombatantTalentEffect] = [
        // MARK: Wizard

        "wizard_freeze_t1_1": CombatantTalentEffect(
            name: "Persistent Frost",
            description: "Enemy Freeze does not fade between rounds.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    freezeBuildupDoesNotDecay: true
                )
            )
        ),
        "wizard_freeze_t1_2": CombatantTalentEffect(
            name: "Numbing Cold",
            description: "Frozen enemies deal 3 less damage.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    frozenEnemyDamageReductionFlat: 3
                )
            )
        ),
        "wizard_freeze_t2_1": CombatantTalentEffect(
            name: "Thermal Shock",
            description: "Burn damage against Frozen enemies deals 4 bonus Physical damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    burnDamageVsFrozenBonusPhysical: 4
                )
            )
        ),
        "wizard_freeze_t2_2": CombatantTalentEffect(
            name: "Glacial Barrier",
            description: "Gain 3 Block whenever an enemy becomes Frozen.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onEnemyFrozenGainBlock: 3
                )
            )
        ),
        "wizard_freeze_t3_1": CombatantTalentEffect(
            name: "Deep Freeze",
            description: "Frozen enemies cannot gain Block or receive healing.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    frozenEnemyCannotBlockOrHeal: true
                )
            )
        ),
        "wizard_freeze_t3_2": CombatantTalentEffect(
            name: "Blizzard",
            description: "Playing 3 Freeze cards in one turn Freezes the enemy.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    freezeCardsPlayedThisTurnFreezeAll: 3
                )
            )
        ),
        "wizard_burn_t1_1": CombatantTalentEffect(
            name: "Ignition",
            description: "Burn deals 25% more damage to enemies with no Block.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    burnDamageVsNoBlockMultiplier: 1.25
                )
            )
        ),
        "wizard_burn_t1_2": CombatantTalentEffect(
            name: "Wildfire Spread",
            description: "Burn ticks have a 25% chance to increase in potency.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnIncreaseChancePercent: 0.25
                )
            )
        ),
        "wizard_burn_t2_1": CombatantTalentEffect(
            name: "Searing Heat",
            description: "Burn damage ignores all enemy Block and damage reduction.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    burnIgnoresBlockAndMitigation: true
                )
            )
        ),
        "wizard_burn_t2_2": CombatantTalentEffect(
            name: "Fuel the Flames",
            description: "Spending Mana applies 1 Burn to all Burning enemies.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    onSpendManaBurnBurningEnemies: 1
                )
            )
        ),
        "wizard_burn_t3_1": CombatantTalentEffect(
            name: "Supernova",
            description: "Burn damage has a 50% chance to deal double damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    burnDamageDoubleChancePercent: 0.50
                )
            )
        ),
        "wizard_burn_t3_2": CombatantTalentEffect(
            name: "Pyromancer's Spark",
            description: "Restore 1 Mana whenever you deal Burn damage (up to 2 per turn).",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBurnDamageRestoreManaPerTurnCap: 2
                ),
                mana: ManaTriggers(
                    onBurnDamageRestoreManaFlat: 1
                )
            )
        ),
        "wizard_mana_t1_1": CombatantTalentEffect(
            name: "Arcane Focus",
            description: "Deal 1 Burn or add 1 Freeze when you spend Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaRandomDoTFlat: 1
                )
            )
        ),
        "wizard_mana_t1_2": CombatantTalentEffect(
            name: "Mana Shield",
            description: "At the end of your turn, gain 1 Block for each unspent Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    unspentManaConvertsToBlock: true
                )
            )
        ),
        "wizard_mana_t2_1": CombatantTalentEffect(
            name: "Overcharge",
            description: "When you spend 3 Mana to empower a card, your next card deals 35% more damage.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaEmpowerNextCardThreshold: 3,
                    nextCardEmpowerPercent: 0.35
                )
            )
        ),
        "wizard_mana_t2_2": CombatantTalentEffect(
            name: "Arcane Cleansing",
            description: "Spending 3 or more Mana in a turn cleanses 1 negative effect.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaThresholdCleanseCount: 3
                )
            )
        ),
        "wizard_mana_t3_1": CombatantTalentEffect(
            name: "Arcane Surge",
            description: "Starting your turn at full Mana draws 2 cards.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    startTurnFullManaDrawCards: 2
                )
            )
        ),
        "wizard_mana_t3_2": CombatantTalentEffect(
            name: "Spell Echo",
            description: "Your first Skill each battle plays twice.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    firstSkillCardPlaysTwicePerBattle: true
                )
            )
        ),
    ]
}
