import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let risenSkeletonTalents: [String: CombatantTalentEffect] = [
        // MARK: Risen Skeleton

        "risen_skeleton_physical_t1_1": CombatantTalentEffect(
            name: "Bone Shield",
            description: "Gain 2 Block whenever you deal Physical damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onPhysicalDamageGainBlock: 2
                )
            )
        ),
        "risen_skeleton_physical_t1_2": CombatantTalentEffect(
            name: "Bone Burst",
            description: "Attacks have a 25% chance to deal 3 extra damage and grant 2 Block.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    attackBurstChancePercent: 0.25,
                    attackBurstDamage: 3,
                    attackBurstBlock: 2
                )
            )
        ),
        "risen_skeleton_physical_t2_1": CombatantTalentEffect(
            name: "Brittle Strike",
            description: "Physical attacks ignore all Block on Stunned or Frozen enemies.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    physicalIgnoresBlockVsStunnedOrFrozen: true
                )
            )
        ),
        "risen_skeleton_physical_t2_2": CombatantTalentEffect(
            name: "Dense Bones",
            description: "Each hit you take reduces damage you take by 1 (up to 4).",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    toughnessOnHit: 1,
                    toughnessOnHitCap: 4
                )
            )
        ),
        "risen_skeleton_physical_t3_1": CombatantTalentEffect(
            name: "Cleaving Bones",
            description: "Physical attacks apply 1 additional Bleed to the enemy.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    physicalAttackApplyBleed: 1
                )
            )
        ),
        "risen_skeleton_physical_t3_2": CombatantTalentEffect(
            name: "Bone Armor",
            description: "When the Skeleton loses Health, gain 2 Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onSelfHealthLossGainBlock: 2
                )
            )
        ),
        "risen_skeleton_leech_t1_1": CombatantTalentEffect(
            name: "Weaken Soul",
            description: "Leech reduces the target's damage by 2 for 2 turns.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onLeechReduceEnemyStrength: 2,
                    onLeechReduceEnemyStrengthTurns: 2
                )
            )
        ),
        "risen_skeleton_leech_t1_2": CombatantTalentEffect(
            name: "Toxic Touch",
            description: "Leech damage applies 2 Poison to the target.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onLeechApplyPoison: 2
                )
            )
        ),
        "risen_skeleton_leech_t2_1": CombatantTalentEffect(
            name: "Grave Harvest",
            description: "Leeching Health from an enemy below half Health restores 2 additional Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechBonusHealVsLowHealthEnemies: 2
                )
            )
        ),
        "risen_skeleton_leech_t2_2": CombatantTalentEffect(
            name: "Soul Sharing",
            description: "Convert half of Skeleton's damage into Leech healing for the Hero.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    companionDamageLeechesToHeroPercent: 0.5
                )
            )
        ),
        "risen_skeleton_leech_t3_1": CombatantTalentEffect(
            name: "Affliction Siphon",
            description: "Leech heals for double amount against Poisoned or Bleeding targets.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechHealingVsAfflictedMultiplier: 2
                )
            )
        ),
        "risen_skeleton_leech_t3_2": CombatantTalentEffect(
            name: "Necrotic Bleed",
            description: "Leeching Health applies 2 Bleed to the target.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onLeechApplyBleed: 2
                )
            )
        ),
        "risen_skeleton_deathsdoor_t1_1": CombatantTalentEffect(
            name: "Deathrattle",
            description: "Revive at 1 Health with 10 Block the first time you die each battle.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onceDeathReviveHealth: 1,
                    onceDeathReviveBlock: 10
                )
            )
        ),
        "risen_skeleton_deathsdoor_t1_2": CombatantTalentEffect(
            name: "Tenacious Spirit",
            description: "Survive 1 additional lethal blow while on Death's Door.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    deathsDoorExtraLethalProtection: true
                )
            )
        ),
        "risen_skeleton_deathsdoor_t2_1": CombatantTalentEffect(
            name: "Corpse Explosion",
            description: "Deal 8 Physical damage to the enemy when you die.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onDeathDealPhysicalDamageAllEnemies: 8
                )
            )
        ),
        "risen_skeleton_deathsdoor_t2_2": CombatantTalentEffect(
            name: "Deathly Wrath",
            description: "Attacks are guaranteed Critical Hits while on Death's Door.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    guaranteedCritWhileOnDeathsDoor: true
                )
            )
        ),
        "risen_skeleton_deathsdoor_t3_1": CombatantTalentEffect(
            name: "Endless Legion",
            description: "If Death's Door ends while Skeleton is still alive, restore Health to 6 once.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onEnemyDefeatReviveSelfHealth: 6
                )
            )
        ),
        "risen_skeleton_deathsdoor_t3_2": CombatantTalentEffect(
            name: "Lichbone",
            description: "Take 50% less damage from Bleed and Poison, and resist 50% of incoming Stun.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    afflictionResistance: 0.5
                )
            )
        ),
    ]

    static let manaMothTalents: [String: CombatantTalentEffect] = [
        // MARK: Mana Moth

        "mana_moth_mana_t1_1": CombatantTalentEffect(
            name: "Arcane Reservoir",
            description: "Gain 2 Block when you spend Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaBlockFlat: 2
                )
            )
        ),
        "mana_moth_mana_t1_2": CombatantTalentEffect(
            name: "Aetherial Surge",
            description: "Gain 1 bonus Mana on turn 1 and turn 4.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    bonusManaOnTurns: [1, 4]
                )
            )
        ),
        "mana_moth_mana_t2_1": CombatantTalentEffect(
            name: "Mana Cocoon",
            description: "Spending 3 or more Mana in a turn grants 3 Block and 1 Health.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaThresholdBlockThreshold: 3,
                    spendManaThresholdBlockBlock: 3,
                    spendManaThresholdBlockHealth: 1
                )
            )
        ),
        "mana_moth_mana_t2_2": CombatantTalentEffect(
            name: "Aetherial Flow",
            description: "When the Hero spends Mana, Moth's next attack deals 2 additional damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onHeroSpendManaCompanionNextAttackBonus: 2
                )
            )
        ),
        "mana_moth_mana_t3_1": CombatantTalentEffect(
            name: "Prismatic Spark",
            description: "Gain a 25% chance to double all Mana gained.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    manaGainDoubleChancePercent: 0.25
                )
            )
        ),
        "mana_moth_mana_t3_2": CombatantTalentEffect(
            name: "Arcane Burst",
            description: "Spending 5 Mana draws and automatically plays a random card.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaThresholdAutoPlayCard: 5
                )
            )
        ),
        "mana_moth_freeze_t1_1": CombatantTalentEffect(
            name: "Chilling Flutter",
            description: "Basic attacks add 2 Freeze.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    basicAttackFreezeBuildup: 2
                )
            )
        ),
        "mana_moth_freeze_t1_2": CombatantTalentEffect(
            name: "Frost Guard",
            description: "Gain 2 Block when attacking a Frozen enemy.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onAttackFrozenEnemyGainBlock: 2
                )
            )
        ),
        "mana_moth_freeze_t2_1": CombatantTalentEffect(
            name: "Blinding Frost",
            description: "Moth deals 25% additional damage to Frozen enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsFrozenMultiplier: 1.25
                )
            )
        ),
        "mana_moth_freeze_t2_2": CombatantTalentEffect(
            name: "Subzero Mist",
            description: "Frozen enemies have a 20% chance to miss attacks against Moth.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    frozenEnemyMissChanceVsCompanionPercent: 0.20
                )
            )
        ),
        "mana_moth_freeze_t3_1": CombatantTalentEffect(
            name: "Flash Freeze",
            description: "Spending 4 or more Mana on a card instantly Freezes the enemy.",
            triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    spendManaFreezeThreshold: 4
                )
            )
        ),
        "mana_moth_freeze_t3_2": CombatantTalentEffect(
            name: "Frost Nova",
            description: "Deal 4 additional Freeze damage against Frozen enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    frostDamageVsFrozenBonus: 4
                )
            )
        ),
        "mana_moth_burn_t1_1": CombatantTalentEffect(
            name: "Ember Shield",
            description: "Gain 2 Block whenever an ally deals Burn damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onAllyBurnDamageGainBlock: 2
                )
            )
        ),
        "mana_moth_burn_t1_2": CombatantTalentEffect(
            name: "Moth to Flame",
            description: "Gain 1 Mana whenever Burn deals damage (up to 2 per turn).",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBurnDamageRestoreManaPerTurnCap: 2
                ),
                mana: ManaTriggers(
                    onBurnDamageRestoreManaFlat: 1
                )
            )
        ),
        "mana_moth_burn_t2_1": CombatantTalentEffect(
            name: "Critical Burn",
            description: "Burn damage has a 30% chance to deal double damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    burnDamageDoubleChancePercent: 0.30
                )
            )
        ),
        "mana_moth_burn_t2_2": CombatantTalentEffect(
            name: "Combustion",
            description: "Your attacks against Burning enemies deal bonus damage equal to half their current Burn.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    damagePerBurnPotencyPercent: 0.5
                )
            )
        ),
        "mana_moth_burn_t3_1": CombatantTalentEffect(
            name: "Ember Persistence",
            description: "Burn effects fade 50% slower each round.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnDecaySlowPercent: 0.5
                )
            )
        ),
        "mana_moth_burn_t3_2": CombatantTalentEffect(
            name: "Cinder Halo",
            description: "Burning enemies take 1 Holy damage each time Burn deals damage.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBurnTickHolyDamage: 1
                )
            )
        ),
    ]
}
