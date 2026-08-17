import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let lizardScoutTalents: [String: CombatantTalentEffect] = [
        // MARK: Lizard Scout

        "lizard_scout_poison_t1_1": CombatantTalentEffect(
            name: "Cold Blood",
            description: "Deal 2 Poison when you Dodge.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeApplyPoison: 2
                )
            )
        ),
        "lizard_scout_poison_t1_2": CombatantTalentEffect(
            name: "Venomous Skin",
            description: "Apply 2 Poison to attackers when you take damage.",
            triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(
                    onHitAttackerPoison: 2
                )
            )
        ),
        "lizard_scout_poison_t2_1": CombatantTalentEffect(
            name: "Spit Poison",
            description: "When the Hero attacks a Poisoned enemy, apply 1 extra Poison.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onHeroAttackPoisonedEnemyApplyPoison: 1
                )
            )
        ),
        "lizard_scout_poison_t2_2": CombatantTalentEffect(
            name: "Toxiphage",
            description: "Poison damage heals Lizard Scout for half the damage dealt.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDamageLeechPercent: 0.5
                )
            )
        ),
        "lizard_scout_poison_t3_1": CombatantTalentEffect(
            name: "Paralysis",
            description: "Enemies with 6 or more Poison become Stunned.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonThresholdStunAmount: 6
                )
            )
        ),
        "lizard_scout_poison_t3_2": CombatantTalentEffect(
            name: "Venom Spores",
            description: "Poison fades 50% slower each round.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDecaySlowPercent: 0.50
                )
            )
        ),
        "lizard_scout_bleed_t1_1": CombatantTalentEffect(
            name: "Barbed Tail",
            description: "Basic attacks apply 2 Bleed.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    basicAttackApplyBleed: 2
                )
            )
        ),
        "lizard_scout_bleed_t1_2": CombatantTalentEffect(
            name: "Spiny Carapace",
            description: "Attackers suffer 1 Bleed for 2 turns when hitting you.",
            triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(
                    onHitAttackerBleedPotency: 1,
                    onHitAttackerBleedTurns: 2
                )
            )
        ),
        "lizard_scout_bleed_t2_1": CombatantTalentEffect(
            name: "Ferocious Bite",
            description: "Attacks deal 2 additional damage to Bleeding enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBleedingBonus: 2
                )
            )
        ),
        "lizard_scout_bleed_t2_2": CombatantTalentEffect(
            name: "Evasive Reflexes",
            description: "Gain +10% Dodge chance against Bleeding enemies.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeChanceVsBleedingEnemiesBonus: 0.10
                )
            )
        ),
        "lizard_scout_bleed_t3_1": CombatantTalentEffect(
            name: "Frenzied Tail",
            description: "While any enemy is Bleeding, draw 1 extra card each round.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    extraCardDrawWhileEnemyBleeding: true
                )
            )
        ),
        "lizard_scout_bleed_t3_2": CombatantTalentEffect(
            name: "Armor Shred",
            description: "Bleed strips 2 Block from the target each turn.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    bleedStripsBlockPerTurn: 2
                )
            )
        ),
        "lizard_scout_gold_t1_1": CombatantTalentEffect(
            name: "Trophy Scales",
            description: "Earn 5 bonus Gold from every battle.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    victoryGoldFlat: 5
                )
            )
        ),
        "lizard_scout_gold_t1_2": CombatantTalentEffect(
            name: "Hoard Armor",
            description: "At the end of your turn, gain 1 Block for every 5 Gold carried (max 5).",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockPerGoldCollectedEvery: 5
                )
            )
        ),
        "lizard_scout_gold_t2_1": CombatantTalentEffect(
            name: "Pickpocket",
            description: "Attacks steal 1 Gold from the enemy.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    onAttackStealGold: 1
                )
            )
        ),
        "lizard_scout_gold_t2_2": CombatantTalentEffect(
            name: "Scavenger's Cache",
            description: "Spend Gold to prevent damage (1 Gold per 1 damage, up to 5 Gold per hit).",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    goldAbsorbsDamage: true
                )
            )
        ),
        "lizard_scout_gold_t3_1": CombatantTalentEffect(
            name: "Flawless Bounty",
            description: "While the Lizard Scout is at full Health, Gold you gain in combat is doubled.",
            triggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    goldDoubledWhileFullHealth: true
                )
            )
        ),
        "lizard_scout_gold_t3_2": CombatantTalentEffect(
            name: "Gilded Claws",
            description: "Deal 1 bonus damage for every 20 Gold carried.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damagePerCarriedGoldEvery: 20
                )
            )
        ),
    ]

    static let pantherTalents: [String: CombatantTalentEffect] = [
        // MARK: Panther

        "panther_bleed_t1_1": CombatantTalentEffect(
            name: "Razor Claws",
            description: "Increase Bleed damage dealt by 2.",
            modifiers: [.damageDealt(.bleed, 2)]
        ),
        "panther_bleed_t1_2": CombatantTalentEffect(
            name: "Raking Swipes",
            description: "Attacks apply 2 Bleed.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    attackApplyBleed: 2
                )
            )
        ),
        "panther_bleed_t2_1": CombatantTalentEffect(
            name: "Stalk the Wound",
            description: "Bleeding targets take 20% additional damage from Physical attacks.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    physicalDamageVsBleedingMultiplier: 1.2
                )
            )
        ),
        "panther_bleed_t2_2": CombatantTalentEffect(
            name: "Rend Flesh",
            description: "Critical hits double the duration of active Bleed effects.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onCritDoubleBleedDuration: true
                )
            )
        ),
        "panther_bleed_t3_1": CombatantTalentEffect(
            name: "Crippling Laceration",
            description: "Enemies with 3 or more Bleed deal 30% less damage.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    enemyBleedStacksDamageReductionStacks: 3,
                    enemyBleedStacksDamageReductionPercent: 0.30
                )
            )
        ),
        "panther_bleed_t3_2": CombatantTalentEffect(
            name: "Pouncing Finish",
            description: "Attacking a Bleeding target deals 2 additional Physical damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBleedingBonus: 2
                )
            )
        ),
        "panther_leech_t1_1": CombatantTalentEffect(
            name: "Blood Hunger",
            description: "Gain +15% Leech against enemies below half Health.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechPercentVsLowHealthEnemies: 0.15
                )
            )
        ),
        "panther_leech_t1_2": CombatantTalentEffect(
            name: "Shared Feast",
            description: "Leech healing is shared equally with the Hero.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechSharesToHeroPercent: 0.5
                )
            )
        ),
        "panther_leech_t2_1": CombatantTalentEffect(
            name: "Vitality Infusion",
            description: "Leeching Health restores 1 Mana to the Hero.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onCompanionLeechRestoreHeroMana: 1
                )
            )
        ),
        "panther_leech_t2_2": CombatantTalentEffect(
            name: "Sanguine Growth",
            description: "Overhealing from Leech grants a +1 damage bonus for combat (up to +4).",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    leechOverhealDamageBonus: 1
                )
            )
        ),
        "panther_leech_t3_1": CombatantTalentEffect(
            name: "Frenzied Feeding",
            description: "Leeching from Poisoned or Bleeding enemies doubles the healing received.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    leechHealingVsAfflictedMultiplier: 2
                )
            )
        ),
        "panther_leech_t3_2": CombatantTalentEffect(
            name: "Pack Bloodlust",
            description: "While Panther is above 80% Health, party gains +10% Critical Hit chance.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    partyCritChanceWhileCompanionAboveHealthThreshold: 0.8,
                    partyCritChanceWhileCompanionAboveHealthBonus: 0.10
                )
            )
        ),
        "panther_dodge_t1_1": CombatantTalentEffect(
            name: "Surprise Strike",
            description: "Your first attack in battle is a guaranteed Critical Hit.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    firstAttackGuaranteedCritical: true
                )
            )
        ),
        "panther_dodge_t1_2": CombatantTalentEffect(
            name: "Counter Pounce",
            description: "Dodging an attack counters immediately for 3 damage.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeCounterDamage: 3
                )
            )
        ),
        "panther_dodge_t2_1": CombatantTalentEffect(
            name: "Survival Instinct",
            description: "Gain 25% Dodge chance while below 30% Health.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeChanceBelowHealthPercentThreshold: 0.3,
                    dodgeChanceBelowHealthPercentBonus: 0.25
                )
            )
        ),
        "panther_dodge_t2_2": CombatantTalentEffect(
            name: "Stalker's Precision",
            description: "Each Dodge increases your Critical Hit damage by half, up to double.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    critMultiplierPerDodge: 0.5
                )
            )
        ),
        "panther_dodge_t3_1": CombatantTalentEffect(
            name: "Shadow Camouflage",
            description: "Single-target enemy attacks prioritize the Hero over the Panther.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    redirectSingleTargetAttacksToHero: true
                )
            )
        ),
        "panther_dodge_t3_2": CombatantTalentEffect(
            name: "Vanish",
            description: "After Dodging, strike from hiding: your next attack deals double damage.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    nextAttackDoubleAfterDodge: true
                )
            )
        ),
    ]
}
