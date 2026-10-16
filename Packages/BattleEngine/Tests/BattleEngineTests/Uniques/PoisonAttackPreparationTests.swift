import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [false, true])
    func `Knights Answer consumes Poison attack amplification before the next card`(sealedVial: Bool) throws {
        let talentID = sealedVial ? "alchemist_poison_t4_1" : "alchemist_poison_t3_2"
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.criticalChanceBonus = -1
        var context = try battle(["the_knights_answer"], extra: profile, heroBasic: .causticJab)
        if !sealedVial {
            CombatExecutor.run { await CombatTriggerEngine.afterHeroTalentPoisonExpiry(
                sourceID: context.hero.id, target: context.enemy, in: &context,
            ) }
        }
        block(10, owner: .hero, in: &context)

        let answer = context.recordingResult { observation in enemyHit(5, in: &observation) }

        #expect(answer.events.filter {
            $0.kind == .abilityDamage && $0.actorID == context.hero.id && $0.keyword == .poison
        }.map(\.amount) == [2])
        #expect(context.health(of: context.enemy) == 1998)
        #expect(!context.roster.hero.talents.history.preparations.contains(.doublePoison))
        let nextCard = try play(.causticJab, in: &context)
        #expect(nextCard.filter {
            $0.kind == .abilityDamage && $0.actorID == context.hero.id && $0.keyword == .poison
        }.map(\.amount) == [1])
        #expect(context.health(of: context.enemy) == 1997)
    }
}
