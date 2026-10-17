import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct EnemyTraitCompositionTests {
    @Test func `enemy traits retain expected combat profiles`() throws {
        #expect(Set(Self.expectedTraits.keys) == Set(GameContent.enemies.map(\.id)))
        for enemy in GameContent.enemies {
            let expected = try #require(Self.expectedTraits[enemy.id])
            var actual = CombatBuildResolver.build(enemy: enemy).modifiers
            actual.triggerAbilityNames = [:]
            #expect(actual == expected, "\(enemy.name) must retain its approved combat values")
        }
    }

    private static func baseline(modifiers: [AffixModifier], triggers: CombatTraitTriggers) -> CombatModifierProfile {
        var profile = CombatModifierProfile(modifiers: modifiers)
        profile.triggers = triggers
        return profile
    }

    /// Explicit combat expectations independent of the catalog assignments.
    private static let expectedTraits: [String: CombatModifierProfile] = [
        "living_armor": baseline(
            modifiers: [.damageTakenPercent(.bleed, 0.30)],
            triggers: CombatTraitTriggers { $0.blockPerTurn = 1 },
        ),
        "mimic": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers { $0.firstAttackBleedBonus = 2 },
        ),
        "mud_elemental": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.20), .damageTakenPercent(.poison, 0.20)],
            triggers: CombatTraitTriggers(),
        ),
        "necromancer": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers { $0.leechChancePercent = 0.10 },
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
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .poison
                $0.turnRandomDamageAllEnemiesKeywordB = .bleed
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
            },
        ),
        "the_forge_golem": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .stun
                $0.turnRandomDamageAllEnemiesKeywordB = .burn
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
            },
        ),
        "the_frostwarden": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers {
                $0.turnFreezeDamageAllEnemies = 1
                $0.turnFreezeDamageAllEnemiesInterval = 2
            },
        ),
        "the_iron_bear": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .physical
                $0.turnRandomDamageAllEnemiesKeywordB = .stun
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
            },
        ),
        "goblin": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "fire_elemental": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers { $0.onHitAttackerBurn = 1 },
        ),
        "frost_elemental": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers { $0.basicAttackFreezeBuildup = 1 },
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
            triggers: CombatTraitTriggers { $0.firstHitDoubleDamage = true },
        ),
        "ogre": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers { $0.physicalBlockBreakMultiplier = 2.0 },
        ),
        "fire_imp": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "hellhound": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers { $0.damageVsBurningMultiplier = 1.25 },
        ),
        "pyromancer": baseline(
            modifiers: [.damageTakenPercent(.burn, 0.20), .damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "giant_spider": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers { $0.attacksApplyPoison = 1 },
        ),
        "giant_snake": baseline(
            modifiers: [.damageTakenVulnerability(.freeze, 0.30)],
            triggers: CombatTraitTriggers { $0.poisonStripsBlockBeforeHealth = 1 },
        ),
        "blood_cultist": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "dire_wolf": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.10)],
            triggers: CombatTraitTriggers { $0.damageVsBleedingBonus = 1 },
        ),
        "vampire": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30), .damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers {
                $0.nextAttackBonusOnFullHealth = 1
                $0.leechChancePercent = 0.10
            },
        ),
        "the_blood_countess": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .bleed
                $0.turnRandomDamageAllEnemiesKeywordB = .bleed
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
            },
        ),
        "zealot": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers { $0.holyDamageNextAttackHolyBonus = 1 },
        ),
        "cleric": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers {
                $0.blockPerTurn = 1
                $0.holyDamageHealLowestAllyFlat = 1
            },
        ),
        "inquisitor": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers { $0.holyDamageNextAttackHolyBonus = 1 },
        ),
        "paladin": baseline(
            modifiers: [.damageTakenPercent(.holy, 0.30)],
            triggers: CombatTraitTriggers {
                $0.holyDamageBlockFlat = 1
                $0.stunDamageBlockFlat = 1
            },
        ),
        "the_seraph": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .holy
                $0.turnRandomDamageAllEnemiesKeywordB = .holy
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
            },
        ),
        "winter_wolf": baseline(
            modifiers: [.damageTakenVulnerability(.burn, 0.30)],
            triggers: CombatTraitTriggers { $0.basicAttackFreezeBuildup = 1 },
        ),
        "ice_wraith": baseline(
            modifiers: [
                .damageTakenPercent(.physical, 0.30),
                .damageTakenVulnerability(.burn, 0.30),
                .damageTakenVulnerability(.holy, 0.30),
            ],
            triggers: CombatTraitTriggers { $0.frozenEnemyDamageReductionFlat = 1 },
        ),
        "yeti": baseline(
            modifiers: [
                .damageTakenPercent(.freeze, 0.30),
                .damageTakenVulnerability(.burn, 0.30),
                .damageTakenVulnerability(.physical, 0.20),
                .damageTakenVulnerability(.stun, 0.20),
            ],
            triggers: CombatTraitTriggers { $0.onEnemyFrozenGainBlock = 1 },
        ),
        "banshee": baseline(
            modifiers: [.damageTakenVulnerability(.holy, 0.30)],
            triggers: CombatTraitTriggers { $0.damageWhileTargetStunnedBonus = 1 },
        ),
        "brawler": baseline(
            modifiers: [.damageTakenVulnerability(.bleed, 0.30)],
            triggers: CombatTraitTriggers { $0.stunnedEnemyNextTurnDamageMultiplier = 0.75 },
        ),
        "stone_golem": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers {
                $0.blockPerTurn = 1
                $0.shieldDamageBonusWhileBlocked = 1
            },
        ),
        "earth_elemental": baseline(
            modifiers: [.damageTakenPercent(.physical, 0.10), .damageTakenVulnerability(.stun, 0.30)],
            triggers: CombatTraitTriggers(),
        ),
        "the_stone_titan": baseline(
            modifiers: [],
            triggers: CombatTraitTriggers {
                $0.turnRandomDamageAllEnemiesKeywordA = .physical
                $0.turnRandomDamageAllEnemiesKeywordB = .physical
                $0.turnRandomDamageAllEnemiesAmount = 1
                $0.turnRandomDamageAllEnemiesInterval = 2
                $0.onHealthLossNextDamageReduction = 1
            },
        ),
    ]
}
