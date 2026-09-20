import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct EnemyTraitCompositionTests {
    @Test func `split traits preserve every enemy combat profile`() throws {
        #expect(Set(Self.originalTraits.keys) == Set(GameContent.enemies.map(\.id)))
        for enemy in GameContent.enemies {
            let expected = try #require(Self.originalTraits[enemy.id])
            var actual = CombatBuildResolver.build(enemy: enemy).modifiers
            actual.triggerAbilityNames = [:]
            #expect(actual == expected, "\(enemy.name) must retain all combat values")
        }
    }

    private static func baseline(modifiers: [AffixModifier], triggers: CombatTraitTriggers) -> CombatModifierProfile {
        var profile = CombatModifierProfile(modifiers: modifiers)
        profile.triggers = triggers
        return profile
    }

    /// Captured before splitting the enemy bundles; independent of the new catalog assignments.
    private static let originalTraits: [String: CombatModifierProfile] = [
        "living_armor": baseline(
            modifiers: [.damageTakenPercent(.bleed, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(blockPerTurn: 1)),
        ),
        "mimic": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(damage: DamageTriggers(firstAttackBleedBonus: 2)),
        ),
        "mud_elemental": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.20), .damageTakenPercent(.poison, 0.20)],
            triggers: CombatTraitTriggers(),
        ),
        "necromancer": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(healing: HealingTriggers(leechChancePercent: 0.10)),
        ),
        "plague_doctor": baseline(
            modifiers: [.damageTakenPercent(.poison, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "skeleton": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30), .damageTakenPercent(.bleed, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "the_blight_treant": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .poison,
                turnRandomDamageAllEnemiesKeywordB: .bleed,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
        "the_forge_golem": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .stun,
                turnRandomDamageAllEnemiesKeywordB: .burn,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
        "the_frostwarden": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(control: ControlTriggers(turnFreezeDamageAllEnemies: 1, turnFreezeDamageAllEnemiesInterval: 2)),
        ),
        "the_iron_bear": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .physical,
                turnRandomDamageAllEnemiesKeywordB: .stun,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
        "goblin": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "fire_elemental": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(onHit: OnHitTriggers(onHitAttackerBurn: 1)),
        ),
        "frost_elemental": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(attack: AttackTriggers(basicAttackFreezeBuildup: 1)),
        ),
        "slime": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.10), .damageTakenPercent(.poison, 0.10)],
            triggers: CombatTraitTriggers(),
        ),
        "will_o_wisp": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.30), .damageTakenPercent(.freeze, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "bandit": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(firstHitDoubleDamage: true)),
        ),
        "ogre": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(physicalBlockBreakMultiplier: 2.0)),
        ),
        "fire_imp": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "hellhound": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(damageVsBurningMultiplier: 1.25)),
        ),
        "pyromancer": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(burnIgnoresBlockAndMitigation: true)),
        ),
        "giant_spider": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(attack: AttackTriggers(attacksApplyPoison: 1)),
        ),
        "giant_snake": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(poisonStripsBlockBeforeHealth: 1)),
        ),
        "blood_cultist": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "dire_wolf": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.10)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(damageVsBleedingBonus: 1)),
        ),
        "vampire": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30), .damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(
                attack: AttackTriggers(nextAttackBonusOnFullHealth: 1),
                healing: HealingTriggers(leechChancePercent: 0.10),
            ),
        ),
        "the_blood_countess": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .bleed,
                turnRandomDamageAllEnemiesKeywordB: .bleed,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
        "zealot": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers(attack: AttackTriggers(holyDamageNextAttackHolyBonus: 1)),
        ),
        "cleric": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(block: BlockTriggers(blockPerTurn: 1), healing: HealingTriggers(holyDamageHealLowestAllyFlat: 1)),
        ),
        "inquisitor": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers(attack: AttackTriggers(holyDamageNextAttackHolyBonus: 1)),
        ),
        "paladin": baseline(
            modifiers: [.damageTakenPercent(.holy, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(holyDamageBlockFlat: 1, stunDamageBlockFlat: 1)),
        ),
        "the_seraph": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .holy,
                turnRandomDamageAllEnemiesKeywordB: .holy,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
        "winter_wolf": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(attack: AttackTriggers(basicAttackFreezeBuildup: 1)),
        ),
        "ice_wraith": baseline(
            modifiers: [
                .damageTakenPercent(.physical, 0.30),
                .damageTakenVulnerability(.burn, 0.30),
                .damageTakenVulnerability(.holy, 0.30),
            ],
            triggers: CombatTraitTriggers(mitigation: MitigationTriggers(frozenEnemyDamageReductionFlat: 1)),
        ),
        "yeti": baseline(
            modifiers: [.damageTakenPercent(.freeze, 0.30), .damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(block: BlockTriggers(onEnemyFrozenGainBlock: 1)),
        ),
        "banshee": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(damage: DamageTriggers(damageWhileTargetStunnedBonus: 1)),
        ),
        "brawler": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers(mitigation: MitigationTriggers(stunnedEnemyNextTurnDamageMultiplier: 0.5)),
        ),
        "stone_golem": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(block: BlockTriggers(blockPerTurn: 1, shieldDamageBonusWhileBlocked: 1)),
        ),
        "earth_elemental": baseline(
            modifiers: [.damageTakenPercent(.freeze, 0.20), .damageTakenPercent(.burn, 0.20)],
            triggers: CombatTraitTriggers(block: BlockTriggers(onEnemyBlockBrokenDealPhysical: 1)),
        ),
        "the_stone_titan": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers(damage: DamageTriggers(
                turnRandomDamageAllEnemiesKeywordA: .physical,
                turnRandomDamageAllEnemiesKeywordB: .physical,
                turnRandomDamageAllEnemiesAmount: 1,
                turnRandomDamageAllEnemiesInterval: 2,
            )),
        ),
    ]
}
