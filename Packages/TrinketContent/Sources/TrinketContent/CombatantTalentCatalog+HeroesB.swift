import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let rangerTalents: [String: CombatantTalentEffect] = [
        // MARK: Ranger

        "ranger_poison_t1_1": CombatantTalentEffect(
            name: "Venomous Arrows",
            description: "Basic attacks apply 2 Poison.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    attacksApplyPoison: 2
                )
            )
        ),
        "ranger_poison_t1_2": CombatantTalentEffect(
            name: "Paralytic Poison",
            description: "Poisoned enemies have a 15% chance to miss their attacks.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    poisonedEnemyMissChancePercent: 0.15
                )
            )
        ),
        "ranger_poison_t2_1": CombatantTalentEffect(
            name: "Prey on the Weak",
            description: "Companion attacks against Poisoned enemies deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    companionDamageVsPoisonedBonus: 2
                )
            )
        ),
        "ranger_poison_t2_2": CombatantTalentEffect(
            name: "Toxic Backlash",
            description: "When Poison is Cleansed, the enemy takes 3 damage per Poison removed.",
            triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    onCleansePoisonDealDamagePerStack: 3
                )
            )
        ),
        "ranger_poison_t3_1": CombatantTalentEffect(
            name: "Corrosive Venom",
            description: "Poison strips 2 Block before damaging Health.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    poisonStripsBlockBeforeHealth: 2
                )
            )
        ),
        "ranger_poison_t3_2": CombatantTalentEffect(
            name: "Lethal Dose",
            description: "Poison damage is doubled against enemies below half Health.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    poisonDamageBelowHealthThreshold: 0.5,
                    poisonDamageBelowHealthMultiplier: 2
                )
            )
        ),
        "ranger_burn_t1_1": CombatantTalentEffect(
            name: "Flaming Arrows",
            description: "Critical hits apply 2 Burn.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    criticalApplyBurn: 2
                )
            )
        ),
        "ranger_burn_t1_2": CombatantTalentEffect(
            name: "Slow Burn",
            description: "Enemies lose 40% less Burn at the end of each round.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnDecaySlowPercent: 0.40
                )
            )
        ),
        "ranger_burn_t2_1": CombatantTalentEffect(
            name: "Cauterize",
            description: "Burn damage consumes Bleed to trigger its remaining damage instantly.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBurnDamageDetonateBleed: true
                )
            )
        ),
        "ranger_burn_t2_2": CombatantTalentEffect(
            name: "Smoke Screen",
            description: "Inflicting Burn grants +10% Dodge chance until your next turn.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onApplyBurnDodgeChanceUntilNextTurn: 0.10
                )
            )
        ),
        "ranger_burn_t3_1": CombatantTalentEffect(
            name: "Scorched Earth",
            description: "Companion attacks deal 2 additional damage to Burning enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    companionDamageVsBurningBonus: 2
                )
            )
        ),
        "ranger_burn_t3_2": CombatantTalentEffect(
            name: "Inferno Barrage",
            description: "Your Ultimate applies 8 Burn.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    ultimateAppliesBurnPotency: 8
                )
            )
        ),
        "ranger_bleed_t1_1": CombatantTalentEffect(
            name: "Lead the Hunt",
            description: "Increase Companion Bleed damage dealt by 3.",
            modifiers: [.companionBleedDamageDealt(3)]
        ),
        "ranger_bleed_t1_2": CombatantTalentEffect(
            name: "Broadhead Arrows",
            description: "Attacks have a 50% chance to apply 1 Bleed.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    directHitBleedChancePercent: 0.5
                )
            )
        ),
        "ranger_bleed_t2_1": CombatantTalentEffect(
            name: "Hamstring Shot",
            description: "A Bleeding enemy has a 15% chance to skip its action each round.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    bleedingEnemyActionSkipChancePercent: 0.15
                )
            )
        ),
        "ranger_bleed_t2_2": CombatantTalentEffect(
            name: "Hunter's Mark",
            description: "Increase Companion Bleed duration by 1 and Bleed damage dealt by 3.",
            modifiers: [.bleedDuration(1), .companionBleedDamageDealt(3)]
        ),
        "ranger_bleed_t3_1": CombatantTalentEffect(
            name: "Pinning Strike",
            description: "Bleeding enemies take 2 damage whenever they attack.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    bleedingEnemyAttackDealDamage: 2
                )
            )
        ),
        "ranger_bleed_t3_2": CombatantTalentEffect(
            name: "Blood Tracker",
            description: "Gain +15% Critical Hit chance against Bleeding enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    critChancePerBleedingEnemy: 0.15
                )
            )
        ),
    ]

    static let warlockTalents: [String: CombatantTalentEffect] = [
        // MARK: Warlock

        "warlock_burn_t1_1": CombatantTalentEffect(
            name: "Bloodfire",
            description: "Whenever Burn damages an enemy, restore 2 Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    burnDamageHealFlat: 2
                )
            )
        ),
        "warlock_burn_t1_2": CombatantTalentEffect(
            name: "Scorching Ash",
            description: "Increase Burn damage dealt by 2.",
            modifiers: [.damageDealt(.burn, 2)]
        ),
        "warlock_burn_t2_1": CombatantTalentEffect(
            name: "Withering Flame",
            description: "Burn reduces enemy healing and Leech by half.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    burnReducesEnemyHealingAndLeechPercent: 0.5
                )
            )
        ),
        "warlock_burn_t2_2": CombatantTalentEffect(
            name: "Soul Burn",
            description: "Restore 1 Mana whenever Burn deals 4 or more damage in a turn.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnDamageManaRestoreThreshold: 4
                ),
                mana: ManaTriggers(
                    onBurnDamageRestoreManaFlat: 1
                )
            )
        ),
        "warlock_burn_t3_1": CombatantTalentEffect(
            name: "Damnation",
            description: "Burning enemies take 25% additional damage from all sources.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBurningMultiplier: 1.25
                )
            )
        ),
        "warlock_burn_t3_2": CombatantTalentEffect(
            name: "Raging Inferno",
            description: "Burn ticks twice per turn on the enemy.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnTicksTwicePerTurn: true
                )
            )
        ),
        "warlock_leech_t1_1": CombatantTalentEffect(
            name: "Vampiric Touch",
            description: "Your Leech heals you even when striking enemy Block.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechOnBlockDamage: true
                )
            )
        ),
        "warlock_leech_t1_2": CombatantTalentEffect(
            name: "Armor Pierce",
            description: "Leech damage ignores the enemy's Toughness.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    leechIgnoresMitigation: true
                )
            )
        ),
        "warlock_leech_t2_1": CombatantTalentEffect(
            name: "Blood Link",
            description: "Overhealing from Leech is transferred to your Companion.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechOverhealTransfersToCompanion: true
                )
            )
        ),
        "warlock_leech_t2_2": CombatantTalentEffect(
            name: "Soul Drain",
            description: "Leeching Health restores 1 Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    leechRestoreManaFlat: 1
                )
            )
        ),
        "warlock_leech_t3_1": CombatantTalentEffect(
            name: "Sanguine Overflow",
            description: "Reaching full Health makes your next attack deal 6 additional damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    nextAttackBonusOnFullHealth: 6
                )
            )
        ),
        "warlock_leech_t3_2": CombatantTalentEffect(
            name: "Soul Ward",
            description: "Whenever an enemy loses Health from an attack, gain 1 Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onAnyHealthLossGainBlock: 1
                )
            )
        ),
        "warlock_mana_t1_1": CombatantTalentEffect(
            name: "Dark Recovery",
            description: "The first time you reach 0 Mana each battle, immediately restore 2 Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    onReachZeroManaRestoreMana: 2
                )
            )
        ),
        "warlock_mana_t1_2": CombatantTalentEffect(
            name: "Forbidden Lore",
            description: "Start each battle with 1 extra Mana.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    startBattleBonusMana: 1
                )
            )
        ),
        "warlock_mana_t2_1": CombatantTalentEffect(
            name: "Eldritch Shield",
            description: "Spending Mana grants 2 Block.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaBlockFlat: 2
                )
            )
        ),
        "warlock_mana_t2_2": CombatantTalentEffect(
            name: "Hexing Rune",
            description: "Spending Mana applies 1 Bleed, Burn, or Poison to a random enemy.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    onHeroSpendManaApplyRandomAffliction: true
                )
            )
        ),
        "warlock_mana_t3_1": CombatantTalentEffect(
            name: "Chaos Rift",
            description: "Spending 4 Mana in a turn deals 8 damage across 2 random elements.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaChaosRiftThreshold: 4,
                    spendManaChaosRiftDamage: 8
                )
            )
        ),
        "warlock_mana_t3_2": CombatantTalentEffect(
            name: "Life Tap",
            description: "Gaining Mana restores 2 Health.",
            triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    onGainManaHealFlat: 2
                )
            )
        ),
    ]
}
