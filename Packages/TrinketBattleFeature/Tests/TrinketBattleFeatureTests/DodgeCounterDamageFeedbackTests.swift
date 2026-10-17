import Foundation
import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature
@testable import TrinketContent

struct DodgeCounterDamageFeedbackTests {
    @Test func `Whiplash folds its prepared bonus into one attack damage chip after Block`() throws {
        let hero = CombatantFixtures.passiveHero()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 100)
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers { $0.dodgeNextStunAttackBonus = 3 })
        var battle = BattleState(
            hero: hero, companion: CombatantFixtures.passiveCompanion(), enemy: enemy,
            heroModifiers: profile, rngSeed: CombatantFixtures.deterministicBattleSeed,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(1, on: enemy, in: &battle)
        let before = battle.health(of: enemy)

        let dodgeEvents = CombatExecutor.run {
            await battle.collectingEvents { battle in
                await CombatTriggerEngine.afterDodge(by: hero, attackerID: enemy.id, in: &battle)
            }
        }
        #expect(battle.health(of: enemy) == before)
        #expect(CombatFeedbackPresenter.makeItems(from: dodgeEvents, at: .now).isEmpty)
        let ability = Ability(
            id: "whiplash-feedback", name: "Stun Attack", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .stun)],
            criticalChanceBonus: -1,
        )
        let events = CombatExecutor.run {
            await battle.collectingEvents { battle in
                await BattleTurnEngine.performAction(ability: ability, actor: hero, abilityTarget: enemy, context: &battle)
            }
        }
        let healthLost = before - battle.health(of: enemy)
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)

        #expect(healthLost == 3)
        #expect(items.count == 1)
        let chip = try #require(items.first)
        #expect(chip.feedbackClass == .directDamage)
        #expect(chip.label == .amount(-healthLost))
        #expect(chip.keyword == .stun)
        #expect(chip.targetID == enemy.id)
        #expect(chip.sourceEventIDs.count == 1)
    }
}
