import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DoTDamageTests {
    private enum TickBonusCase {
        case intellectStat
        case itemDamageDealt
    }

    private func makeContext(
        sourceStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleEngineContext {
        BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            sourcePrimaryStats: sourceStats,
            heroModifiers: heroModifiers,
            seed: seed
        )
    }

    @Test func resolveTickStoresBasePotencyOnStack() throws {
        var context = makeContext()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 4,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            dealImmediateDamage: false,
            in: &context
        )
        let potency = context.roster.enemy.activeEffects.first { $0.keyword == .burn }?.effect.potency
        try #expect(potency == 4)
    }

    @Test(arguments: [TickBonusCase.intellectStat, .itemDamageDealt])
    func resolveTickAppliesDamageBonuses(caseKind: TickBonusCase) throws {
        let context: BattleEngineContext
        let expectedHealthLost: Int
        switch caseKind {
        case .intellectStat:
            // intellect 20 → +4 burn
            context = makeContext(sourceStats: PrimaryStats(intellect: 20))
            expectedHealthLost = 8
        case .itemDamageDealt:
            var modifiers = CombatModifierProfile.zero
            modifiers.damageDealtBonus[.burn] = 3
            context = makeContext(heroModifiers: modifiers)
            expectedHealthLost = 7
        }

        var mutable = context
        let outcome = DoTDamage.resolveTick(
            basePotency: 4,
            keyword: .burn,
            target: mutable.roster.enemy.combatant,
            sourceActorID: "source",
            in: &mutable
        )
        try #expect(outcome.healthLost == expectedHealthLost)
        if case .intellectStat = caseKind {
            try #expect(outcome.events.contains { $0.kind == .status && $0.amount == 8 })
        }
    }

    @Test func resolveTickIncludesStatusEventWhenDamageDealt() throws {
        var context = makeContext()
        let outcome = DoTDamage.resolveTick(
            basePotency: 5,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        try #expect(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }
}
