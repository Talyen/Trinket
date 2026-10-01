import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct OpeningTraitBlockTests {
    @Test(arguments: [false, true])
    func `Watchful Guard protects the opening round and grants once on the next round`(paced: Bool) throws {
        let definition = try #require(GameContent.enemy(matching: "cleric"))
        let build = CombatBuildResolver.build(enemy: definition)
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 50),
            enemy: build.combatant,
            enemyModifiers: build.modifiers,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        if paced {
            while battle.drawNextOpeningHandCard(rebuildLog: false) {}
            battle.finalizeOpeningHand(rebuildLog: false)
        } else {
            battle.drawOpeningHand(rebuildLog: false)
        }

        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 1)
        #expect(battle.events.count(where: { $0.abilityName == "Watchful Guard" }) == 1)
        let hit = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.enemy,
            keyword: .physical,
            sourceActorID: battle.hero.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(hit.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 0)

        let events = battle.endTurn(rebuildLog: false)
        #expect(battle.turnCount == 1)
        #expect(events.count(where: { $0.abilityName == "Watchful Guard" }) == 1)
    }

    @Test func `opening round Block skips defeated owners`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockPerTurn = 1
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: profile,
            companionModifiers: profile,
            enemyModifiers: profile,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        battle.drawOpeningHand(rebuildLog: false)

        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 1)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 1)
    }
}
