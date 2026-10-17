import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsFeedbackRegressionTests {
    @Test(arguments: ["obsidian_hammer", "vanguards_crest"])
    func `Retaliatory preserves nested trinket feedback and reports reflected Health damage`(trinketID: String) throws {
        let armor = try #require(GameContent.itemAffixDefinition(matching: "retaliatory"))
        let trinket = try #require(GameContent.itemAffixDefinition(matching: trinketID))
        var profile = CombatModifierProfile.zero
        armor.astral.triggers.apply(to: &profile, abilityName: armor.title)
        trinket.basic.triggers.apply(to: &profile, abilityName: trinket.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(outcome.value.healthLost == 10)
        #expect(battle.roster.enemy.currentHealth == 7)
        let reflection = outcome.events.filter { $0.effectKind == .thornsTriggered }
        #expect(reflection.count == 1)
        #expect(reflection.first?.amount == 3)
        #expect(reflection.first?.keyword == .physical)
        #expect(reflection.first?.targetID == battle.enemy.id)
        #expect(reflection.first?.abilityName == "Retaliatory")
        if trinketID == "obsidian_hammer" {
            #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
            #expect(outcome.events.contains {
                $0.effectKind == .controlTriggered && $0.keyword == .stun
                    && $0.targetID == battle.enemy.id && $0.abilityName == "Stunned"
            })
        } else {
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 2)
            #expect(outcome.events.contains {
                $0.effectKind == .shieldApplied && $0.targetID == battle.hero.id
                    && $0.amount == 2 && $0.abilityName == "Martial Guard"
            })
        }
    }
}
