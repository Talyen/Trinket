import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test func `Beacon heals on the first damaging Holy attack per turn without spending its allowance on Thorns or Block`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t2_1"])
        let beacon = try #require(GameContent.itemAffixDefinition(matching: "beacon"))
        beacon.basic.triggers.apply(to: &profile, abilityName: beacon.title)
        profile.triggers.criticalChanceBonus = -1
        var context = try battle([], extra: profile)
        context.roster.hero.currentHealth = 10
        context.roster.companion.currentHealth = 20
        context.insertEffect(.thorns(4), to: context.hero, sourceID: context.hero.id, remainingTurns: 0)

        let events = context.recordingResult { observation in enemyHit(1, in: &observation) }.events
        #expect(context.health(of: context.enemy) == 1996)
        #expect(context.health(of: context.hero) == 9)
        #expect(!events.contains { $0.abilityName == "Beacon" })
        let attack = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        block(10, owner: .enemy, in: &context)
        _ = context.resolveTestDamage(10, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 9)
        let first = context.recordingResult { context in context.resolveTestDamage(1, keyword: .holy, options: attack) }
        #expect(context.health(of: context.hero) == 11)
        #expect(first.events.filter { $0.abilityName == "Beacon" && $0.effectKind == .instantHeal }.map(\.amount) == [2])
        _ = context.resolveTestDamage(1, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 11)
        context.turnCount += 1
        _ = context.resolveTestDamage(1, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 13)
    }

    @Test func `Rimeheart grants Block for Blizzard's immediate and lingering Freeze damage`() throws {
        var context = try battle(["rimeheart_locket"])
        let applied = CombatExecutor.run {
            await EffectApplication(
                effect: .recurringDamage(.freeze, 6, 1),
                ability: .blizzard,
                source: context.hero,
                target: context.enemy,
            ).apply(in: &context)
        }
        #expect(applied.didApply)
        #expect(context.health(of: context.enemy) == 1994)
        #expect(blockAmount(.hero, in: context) == 6)

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(context.health(of: context.enemy) == 1988)
        #expect(blockAmount(.hero, in: context) == 12)
    }

    @Test(arguments: [false, true])
    func `Rimeheart's lingering Freeze grants Mana only to a living wearer`(defeated: Bool) throws {
        var context = try battle(["rimeheart_locket"])
        context.roster.hero.currentHealth = defeated ? 0 : 200
        block(3, owner: .hero, in: &context)
        let threshold = ControlMeterEngine.threshold(for: context.enemy, in: context)
        context.insertEffect(
            .recurringDamage(.freeze, threshold, 1), to: context.enemy,
            sourceID: context.hero.id, remainingTurns: 1,
        )

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }

        #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .freeze))
        #expect(context.roster.hero.currentMana == (defeated ? 0 : 3))
    }

    @Test(arguments: [false, true])
    func `Golden Verdict grants Gold for committed Holy Thorns only while its wearer lives`(defeated: Bool) throws {
        var context = try battle(["golden_verdict"], extra: CombatantTalentCatalog.profile(for: ["knight_holy_t2_1"]))
        context.roster.hero.currentHealth = 1
        context.roster.hero.hasConsumedDeathsDoor = defeated
        let threshold = ControlMeterEngine.threshold(for: context.enemy, in: context)
        context.insertEffect(.thorns(threshold), to: context.hero, sourceID: context.hero.id, remainingTurns: 0)

        _ = enemyHit(1, in: &context)

        #expect(context.health(of: context.hero) == (defeated ? 0 : 1))
        #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .stun))
        #expect(context.gold == (defeated ? 0 : 1))
    }
}
