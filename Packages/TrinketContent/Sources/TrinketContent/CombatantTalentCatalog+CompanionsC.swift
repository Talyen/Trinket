import Foundation
import TrinketCore

extension CombatantTalentCatalog {
    static let phoenixTalents: [String: CombatantTalentEffect] = [
        // MARK: Phoenix

        "phoenix_burn_t1_1": CombatantTalentEffect(
            name: "Blazing Feathers",
            description: "Attackers suffer 2 Burn when hitting the Phoenix.",
            triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(
                    onHitAttackerBurn: 2
                )
            )
        ),
        "phoenix_burn_t1_2": CombatantTalentEffect(
            name: "Ignition Spark",
            description: "Burn has a 25% chance to increase instead of decrease.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnIncreaseChancePercent: 0.25
                )
            )
        ),
        "phoenix_burn_t2_1": CombatantTalentEffect(
            name: "Flame Shield",
            description: "Gain 2 Block whenever you deal Burn damage.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onBurnDamageGainBlock: 2
                )
            )
        ),
        "phoenix_burn_t2_2": CombatantTalentEffect(
            name: "Explosive Embers",
            description: "Phoenix deals 4 additional damage to Burning enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    companionDamageVsBurningBonus: 4
                )
            )
        ),
        "phoenix_burn_t3_1": CombatantTalentEffect(
            name: "Molten Heat",
            description: "Burn damage ignores all enemy Block and resistance.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    burnIgnoresBlockAndMitigation: true
                )
            )
        ),
        "phoenix_burn_t3_2": CombatantTalentEffect(
            name: "Intense Heat",
            description: "Burning enemies take 25% additional damage from all sources.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBurningMultiplier: 1.25
                )
            )
        ),
        "phoenix_health_t1_1": CombatantTalentEffect(
            name: "Restorative Ashes",
            description: "Regenerate 2 Health every turn.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    healthPerTurn: 2
                )
            )
        ),
        "phoenix_health_t1_2": CombatantTalentEffect(
            name: "Healing Flames",
            description: "Dealing Burn damage heals the lowest Health ally for 2.",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onBurnDamageHealLowestAllyFlat: 2
                )
            )
        ),
        "phoenix_health_t2_1": CombatantTalentEffect(
            name: "Afterglow",
            description: "When the Phoenix survives Death's Door, restore 15% of each ally's Max Health.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    surviveDeathsDoorPartyHealPercent: 0.15
                )
            )
        ),
        "phoenix_health_t2_2": CombatantTalentEffect(
            name: "Radiant Health",
            description: "While Phoenix is at full Health, party attacks deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    partyDamageBonusWhileCompanionFullHealth: 2
                )
            )
        ),
        "phoenix_health_t3_1": CombatantTalentEffect(
            name: "Phoenix Gift",
            description: "The first time each battle the Hero would take fatal damage, heal them for 15% Max Health.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onHeroFatalHealPercentMaxHealth: 0.15
                )
            )
        ),
        "phoenix_health_t3_2": CombatantTalentEffect(
            name: "Ashen Vitality",
            description: "Overhealing converts into Max Health this combat (up to +10).",
            triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToMaxHealth: true,
                    overhealConvertsToMaxHealthCap: 10
                )
            )
        ),
        "phoenix_deathsdoor_t1_1": CombatantTalentEffect(
            name: "From the Ashes",
            description: "Revives and restores 10 Health the first time it dies each battle. This happens before Death's Door.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onceDeathReviveHealth: 10
                )
            )
        ),
        "phoenix_deathsdoor_t1_2": CombatantTalentEffect(
            name: "Lingering Spirit",
            description: "Death's Door lasts 1 additional turn.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    deathsDoorDurationBonusTurns: 1
                )
            )
        ),
        "phoenix_deathsdoor_t2_1": CombatantTalentEffect(
            name: "Blazing Rebirth",
            description: "Rebirth deals 5 Burn damage to the enemy when triggered.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    reviveDealBurnDamage: 5
                )
            )
        ),
        "phoenix_deathsdoor_t2_2": CombatantTalentEffect(
            name: "Phoenix Vigor",
            description: "Surviving Death's Door grants +50% damage for 3 turns.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onSurviveDeathsDoorDamageBonusPercent: 0.5
                )
            )
        ),
        "phoenix_deathsdoor_t3_1": CombatantTalentEffect(
            name: "Fortified Rebirth",
            description: "Revives trigger with 10 Block in addition to Health.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    onceDeathReviveBlock: 10
                )
            )
        ),
        "phoenix_deathsdoor_t3_2": CombatantTalentEffect(
            name: "Ashen Ward",
            description: "Gain +50% Dodge chance and debuff immunity while on Death's Door.",
            triggers: CombatTraitTriggers(
                revival: RevivalTriggers(
                    deathsDoorDodgeAndDebuffImmunity: true
                )
            )
        ),
    ]

    static let wolfTalents: [String: CombatantTalentEffect] = [
        // MARK: Wolf

        "wolf_bleed_t1_1": CombatantTalentEffect(
            name: "Pack Ferocity",
            description: "Increase Bleed duration by 1 and Bleed damage dealt by 1.",
            modifiers: [.bleedDuration(1), .damageDealt(.bleed, 1)]
        ),
        "wolf_bleed_t1_2": CombatantTalentEffect(
            name: "Deep Bite",
            description: "Deal 2 additional damage to Bleeding enemies.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsBleedingBonus: 2
                )
            )
        ),
        "wolf_bleed_t2_1": CombatantTalentEffect(
            name: "Hamstring",
            description: "Bleeding enemies deal 2 less damage.",
            triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(
                    bleedingEnemyDamageReductionFlat: 2
                )
            )
        ),
        "wolf_bleed_t2_2": CombatantTalentEffect(
            name: "Open Wounds",
            description: "Applying Bleed to a Bleeding target deals 2 instant damage.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBleedAppliedToBleedingDealDamage: 2
                )
            )
        ),
        "wolf_bleed_t3_1": CombatantTalentEffect(
            name: "Carnivore",
            description: "Heal 2 Health whenever Bleed deals damage.",
            triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBleedDamageHealSelf: 2
                )
            )
        ),
        "wolf_bleed_t3_2": CombatantTalentEffect(
            name: "Savage Tear",
            description: "Bleed ticks have a 20% chance to critically strike.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    bleedTickCritChancePercent: 0.20
                )
            )
        ),
        "wolf_dodge_t1_1": CombatantTalentEffect(
            name: "Sidestep",
            description: "Gain 2 Block whenever you Dodge.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeBlockFlat: 2
                )
            )
        ),
        "wolf_dodge_t1_2": CombatantTalentEffect(
            name: "Nimble Fang",
            description: "After Dodging, your next attack inflicts 2 Bleed.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    nextAttackBleedAfterDodge: 2
                )
            )
        ),
        "wolf_dodge_t2_1": CombatantTalentEffect(
            name: "Pack Coordination",
            description: "When Wolf Dodges, the Hero gains +10% Dodge until your next turn.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onCompanionDodgeGrantHeroDodgePercent: 0.10
                )
            )
        ),
        "wolf_dodge_t2_2": CombatantTalentEffect(
            name: "Flanking Position",
            description: "Dodging makes your next party hit a guaranteed Critical Hit.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeNextPartyHitGuaranteedCritical: true
                )
            )
        ),
        "wolf_dodge_t3_1": CombatantTalentEffect(
            name: "Evasive Pack",
            description: "Wolf automatically Dodges attacks after the first hit each turn. These Dodges do not counterattack.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    autoDodgeAfterFirstHitPerTurn: true
                )
            )
        ),
        "wolf_dodge_t3_2": CombatantTalentEffect(
            name: "Snapping Jaws",
            description: "Dodging counters with an immediate basic attack.",
            triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    onDodgeCounterBasicAttack: true
                )
            )
        ),
        "wolf_physical_t1_1": CombatantTalentEffect(
            name: "Alpha Howl",
            description: "Party deals 2 additional Physical damage for the first 3 turns.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    partyPhysicalDamageBonusFirstTurns: 2,
                    partyPhysicalDamageBonusFirstTurnCount: 3
                )
            )
        ),
        "wolf_physical_t1_2": CombatantTalentEffect(
            name: "Predatory Focus",
            description: "Deal 3 additional damage to enemies with lower Health than Wolf.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageVsLowerHealthEnemyBonus: 3
                )
            )
        ),
        "wolf_physical_t2_1": CombatantTalentEffect(
            name: "Bone-Crushing Bite",
            description: "Physical attacks ignore half of enemy Block.",
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    physicalBlockIgnorePercent: 0.5
                )
            )
        ),
        "wolf_physical_t2_2": CombatantTalentEffect(
            name: "Alpha Might",
            description: "While the enemy is below half Health, party Physical attacks deal 2 additional damage.",
            triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageBelowHealthPercentThreshold: 0.5,
                    damageBelowHealthPercentKeyword: .physical,
                    damageBelowHealthPercentBonus: 2
                )
            )
        ),
        "wolf_physical_t3_1": CombatantTalentEffect(
            name: "Feral Frenzy",
            description: "While the enemy is below 40% Health, the Wolf draws 1 extra card each round.",
            triggers: CombatTraitTriggers(
                enemyTurn: EnemyTurnTriggers(
                    extraCardDrawBelowEnemyHealthPercent: 0.40
                )
            )
        ),
        "wolf_physical_t3_2": CombatantTalentEffect(
            name: "Rending Fangs",
            description: "Physical attacks apply 1 Bleed on hit.",
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(
                    physicalAttackApplyBleed: 1
                )
            )
        ),
    ]
}
