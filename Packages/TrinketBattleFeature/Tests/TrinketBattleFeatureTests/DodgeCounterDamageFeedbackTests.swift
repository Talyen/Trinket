import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

struct DodgeCounterDamageFeedbackTests {
    @Test func `Whiplash floats the Health damage remaining after Block exactly once`() throws {
        let hero = CombatantFixtures.passiveHero()
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 100)
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            control: ControlTriggers(dodgeDealStunFlat: 3),
        ))
        var battle = BattleState(
            hero: hero, companion: CombatantFixtures.passiveCompanion(), enemy: enemy,
            heroModifiers: profile, rngSeed: CombatantFixtures.deterministicBattleSeed,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(1, on: enemy, in: &battle)
        let before = battle.health(of: enemy)

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(by: hero, attackerID: enemy.id, in: &battle) }
        let healthLost = before - battle.health(of: enemy)
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)

        #expect(healthLost == 2)
        #expect(items.count == 1)
        let chip = try #require(items.first)
        #expect(chip.feedbackClass == .directDamage)
        #expect(chip.label == .amount(-healthLost))
        #expect(chip.keyword == .stun)
        #expect(chip.targetID == enemy.id)
        #expect(chip.sourceEventIDs.count == 1)
    }
}
