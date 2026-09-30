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
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(outcome.healthLost == 10)
        #expect(battle.roster.enemy.currentHealth == 8)
        let reflection = outcome.events.filter { $0.effectKind == .thornsTriggered }
        #expect(reflection.count == 1)
        #expect(reflection.first?.amount == 2)
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
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 1)
            #expect(outcome.events.contains {
                $0.effectKind == .shieldApplied && $0.targetID == battle.hero.id
                    && $0.amount == 1 && $0.abilityName == "Martial Guard"
            })
        }
    }
}
