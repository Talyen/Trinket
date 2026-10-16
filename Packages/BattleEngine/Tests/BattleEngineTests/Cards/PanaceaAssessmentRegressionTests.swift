import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PanaceaAssessmentRegressionTests {
    @Test(arguments: [(true, true), (true, false), (false, true)])
    func `Panacea healing cue accounts for damage reactions before healing`(heroAlive: Bool, hasDebuff: Bool) throws {
        var companion = CombatantTalentCatalog.profile(for: ["library_owl_cleanse_t3_1"])
        companion.triggers.criticalChanceBonus = -1
        var enemy = CombatModifierProfile.zero
        enemy.triggers.onBlockHitDealHoly = 2
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroHealth: heroAlive ? 5 : 0, companionHealth: 6,
            companionModifiers: companion, enemyModifiers: enemy, appliesFightPacing: false,
        )
        if hasDebuff {
            state.insertEffect(.poison(1), to: state.companion, sourceID: state.enemy.id, remainingTurns: 2)
        }
        DefensePoolEngine.set(6, on: state.enemy, in: &state)
        let card = BattleCardCombatEngine.deal(.panaceaPotion, owner: .companion, context: &state)

        let rng = state.rng
        let targets = state.assessCard(card).targets
        #expect(state.rng == rng)
        #expect(state.health(of: state.companion) == 6)
        let healingTargets = targets.filter {
            if case .effect(.instantHeal(.health, _)) = $0.intent {
                return true
            }
            return false
        }
        let expectedCue = heroAlive ? state.hero.id : state.companion.id
        #expect(healingTargets.map(\.combatantID) == (heroAlive && hasDebuff ? [] : [expectedCue]))

        // Reproving Light hits the enemy's Block; its response lowers the Companion
        // below the Hero before Panacea chooses whom to heal.
        let events = try state.playCard(cardID: card.id).events
        let heal = try #require(events.first {
            $0.abilityName == Ability.panaceaPotion.name && $0.effectKind == .instantHeal
        })
        #expect(heal.targetID == (hasDebuff || !heroAlive ? state.companion.id : state.hero.id))
    }
}
