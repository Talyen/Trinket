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
        targetStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
    ) -> BattleState {
        BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            targetPrimaryStats: targetStats,
            sourcePrimaryStats: sourceStats,
            heroModifiers: heroModifiers,
            seed: seed,
        )
    }

    @Test func `resolve turn damage applies target toughness mitigation`() {
        var context = makeContext(targetStats: PrimaryStats(toughness: 50))
        let outcome = DoTDamage.resolveTurnDamage(
            basePotency: 4,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context,
        )

        #expect(outcome.healthLost == 2)
        #expect(outcome.events.contains { $0.kind == .status && $0.amount == 2 })
    }

    @Test func `resolve turn damage stores base potency on stack`() throws {
        var context = makeContext()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 4,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            dealImmediateDamage: false,
            in: &context,
        )
        let potency = context.roster.enemy.activeEffects.first { $0.keyword == .burn }?.effect.potency
        try #expect(potency == 4)
    }

    @Test(arguments: [TickBonusCase.intellectStat, .itemDamageDealt])
    private func `resolve turn damage applies damage bonuses`(caseKind: TickBonusCase) throws {
        let context: BattleState
        let expectedHealthLost: Int
        switch caseKind {
        case .intellectStat:
            context = makeContext(sourceStats: PrimaryStats(intellect: 20))
            expectedHealthLost = 5
        case .itemDamageDealt:
            var modifiers = CombatModifierProfile.zero
            modifiers.damageDealtBonus[.burn] = 3
            context = makeContext(heroModifiers: modifiers)
            expectedHealthLost = 7
        }

        var mutable = context
        let outcome = DoTDamage.resolveTurnDamage(
            basePotency: 4,
            keyword: .burn,
            target: mutable.roster.enemy.combatant,
            sourceActorID: "source",
            in: &mutable,
        )
        try #expect(outcome.healthLost == expectedHealthLost)
        if case .intellectStat = caseKind {
            try #expect(outcome.events.contains { $0.kind == .status && $0.amount == 5 })
        }
    }

    @Test func `resolve turn damage includes status event when damage dealt`() throws {
        var context = makeContext()
        let outcome = DoTDamage.resolveTurnDamage(
            basePotency: 5,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context,
        )
        try #expect(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }
}
