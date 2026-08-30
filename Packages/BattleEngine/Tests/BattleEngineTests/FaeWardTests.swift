import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct FaeWardTests {
    private static let faeWard = CombatModifierProfile(
        triggers: CombatTraitTriggers(cleanse: CleanseTriggers(blockFirstDebuffPerTurn: true)),
    )

    private func makeWardedHeroBattle(
        heroModifiers: CombatModifierProfile = Self.faeWard,
        enemyModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: heroModifiers,
            enemyModifiers: enemyModifiers,
            dealOpeningHand: false,
        )
    }

    @Test func `decaying burn is blocked once`() {
        var battle = makeWardedHeroBattle()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 3,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        #expect(burnPotency(on: battle.roster.hero.combatant, in: battle) == nil)
    }

    @Test func `poison stack is blocked once`() {
        var battle = makeWardedHeroBattle()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .poison,
            potency: 4,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        let poisons = battle.roster.activeEffects(for: battle.roster.hero.combatant)
            .filter { $0.effect.keyword == .poison }
        #expect(poisons.isEmpty)
    }

    @Test func `bleed is still blocked once`() {
        var battle = makeWardedHeroBattle()
        _ = DoTApplicator.applyBleed(
            potency: 3,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        let bleeds = battle.roster.activeEffects(for: battle.roster.hero.combatant)
            .filter(\.effect.isBleed)
        #expect(bleeds.isEmpty)
    }

    @Test func `stun meter charge is blocked once`() {
        var battle = makeWardedHeroBattle()
        let events = ControlMeterEngine.applyMeterCharge(
            3,
            keyword: .stun,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            applyFightPacing: false,
            in: &battle,
        )
        #expect(events.isEmpty)
        let meters = battle.roster.activeEffects(for: battle.roster.hero.combatant)
            .filter { $0.effect.keyword == .stun }
        #expect(meters.isEmpty)
    }

    @Test func `marked from stun reaction is blocked once`() {
        var battle = makeWardedHeroBattle(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(enemyStunnedApplyMarked: true),
            )),
            enemyModifiers: Self.faeWard,
        )
        let events = CombatTriggerEngine.afterEnemyStunned(in: &battle)
        #expect(!events.contains(where: { $0.effectKind == .markedApplied }))
        let marks = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
        #expect(!marks)
    }

    @Test func `second negative effect same turn lands after ward consumed`() {
        var battle = makeWardedHeroBattle()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 3,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .poison,
            potency: 2,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        let effects = battle.roster.activeEffects(for: battle.roster.hero.combatant)
        #expect(!effects.contains(where: { $0.effect.keyword == .burn }))
        #expect(effects.contains { $0.effect.keyword == .poison })
    }

    @Test func `combatant without ward keeps taking debuffs`() {
        var battle = makeWardedHeroBattle(heroModifiers: .zero)
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 3,
            to: battle.roster.hero.combatant,
            sourceActorID: battle.roster.enemy.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &battle,
        )
        #expect(burnPotency(on: battle.roster.hero.combatant, in: battle) == 3)
    }

    private func burnPotency(on combatant: Combatant, in battle: BattleState) -> Int? {
        battle.roster.activeEffects(for: combatant)
            .first { $0.effect.keyword == .burn }?.effect.potency
    }
}
