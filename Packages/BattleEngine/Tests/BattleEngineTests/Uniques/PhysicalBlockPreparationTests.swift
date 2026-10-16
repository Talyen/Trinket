import Testing
import TrinketContent
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test func `Knights Answer spends Blind Spot on its Physical Basic attack`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_dodge_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var context = try battle(["the_knights_answer"], extra: profile)
        CombatTriggerEngine.afterHeroTalentDodge(by: context.hero, in: &context)
        block(10, owner: .hero, in: &context)
        block(20, owner: .enemy, in: &context)

        let answer = context.recordingResult { observation in enemyHit(5, in: &observation) }

        #expect(answer.events.filter {
            $0.kind == .abilityDamage && $0.actorID == context.hero.id
        }.map(\.amount) == [3])
        #expect(context.health(of: context.enemy) == 1997)
        #expect(blockAmount(.enemy, in: context) == 20)
        #expect(!context.roster.hero.talents.history.preparations.contains(.ignorePhysicalBlock))
        _ = try play(.slash, in: &context)
        #expect(context.health(of: context.enemy) == 1997)
        #expect(blockAmount(.enemy, in: context) == 17)
    }
}
