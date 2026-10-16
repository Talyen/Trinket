import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeCounterDamageEventsTests {
    @Test(
        arguments: [(Keyword.stun, "whiplash", 3), (.freeze, "frost_whelp_dodge_t2_2", 2), (.bleed, "panther_dodge_t1_2", 2)],
        [false, true],
    )
    func `Dodge bonuses refresh and wait for one later matching attack by their owner`(
        scenario: (Keyword, String, Int),
        card: Bool,
    ) throws {
        let (keyword, id, bonus) = scenario
        var profile = CombatantTalentCatalog.profile(for: [id])
        if keyword == .stun {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100), heroModifiers: profile, appliesFightPacing: false,
        )
        let serial = card ? battle.resolution.beginCard(actorID: battle.hero.id) : nil
        _ = battle.resolution.beginAction(BattleActionContext(actor: battle.hero, in: battle), origin: card ? .card : .counterattack)
        for _ in 0 ..< 2 {
            let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
                by: battle.hero, attackerID: battle.enemy.id, allowsCounterattacks: false, in: &battle,
            ) }
            #expect(!events.contains { $0.kind == .abilityDamage })
        }
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.activeEffects(of: battle.enemy).isEmpty)
        let attack = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        #expect(battle.resolveTestDamage(1, keyword: keyword, options: attack).healthLost == 1)
        battle.resolution.endAction()
        if let serial {
            _ = battle.resolution.beginAction(BattleActionContext(actor: battle.hero, in: battle), origin: .counterattack)
            #expect(battle.resolveTestDamage(1, keyword: keyword, options: attack).healthLost == 1)
            battle.resolution.endAction()
            battle.resolution.endCard(serial)
        }
        #expect(battle.resolveTestDamage(1, keyword: keyword, options: .resolvedPeriodic).healthLost == 1)
        #expect(battle.resolveTestDamage(1, keyword: .physical, options: attack).healthLost == 1)
        #expect(battle.resolveTestDamage(1, from: .companion, keyword: keyword, options: attack).healthLost == 1)
        let events = battle.performTestAction(Ability(
            id: "prepared-pair", name: "Prepared Pair", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: keyword), DamageComponent(1, keyword: keyword)],
            criticalChanceBonus: -1,
        ))
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.amount) == [1 + bonus, 1])
    }

    @Test(arguments: [Keyword.stun, .freeze, .bleed], [false, true])
    func `Dodge counterattacks preserve fresh typed preparations while consuming older readiness`(
        keyword: Keyword,
        alreadyPrepared: Bool,
    ) {
        let basic = Ability(
            id: "typed-counter", name: "Typed Counter", tier: .basic,
            directDamage: 1, damageKeyword: keyword, criticalChanceBonus: -1,
        )
        let profile = CombatModifierProfile.withTriggers {
            $0.dodgeNextStunAttackBonus = keyword == .stun ? 3 : 0
            $0.dodgeNextFreezeAttackBonus = keyword == .freeze ? 3 : 0
            $0.dodgeNextBleedAttackBonus = keyword == .bleed ? 3 : 0
            $0.onDodgeCounterBasicAttack = true
            $0.criticalChanceBonus = -1
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(abilities: [basic]),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100), heroModifiers: profile, appliesFightPacing: false,
        )
        if alreadyPrepared {
            CombatExecutor.run { await CombatTriggerEngine.afterDodge(
                by: battle.hero, attackerID: battle.enemy.id, allowsCounterattacks: false, in: &battle,
            ) }
        }
        battle.insertEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let enemyAttack = Ability(
            id: "incoming-attack", name: "Incoming Attack", tier: .basic,
            directDamage: 1, damageKeyword: .physical, criticalChanceBonus: -1,
        )
        let counterEvents = battle.performTestAction(enemyAttack, from: .enemy, to: .hero)
        #expect(counterEvents.contains { $0.effectKind == .dodgeApplied })
        #expect(counterEvents.filter { $0.kind == .abilityDamage && $0.actorID == battle.hero.id }.map(\.amount)
            == [alreadyPrepared ? 4 : 1])
        #expect(battle.uniques.pendingCounterAttacks.isEmpty)

        let events = battle.performTestAction(basic)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.amount) == [4])
        let laterEvents = battle.performTestAction(basic)
        #expect(laterEvents.filter { $0.kind == .abilityDamage }.map(\.amount) == [1])
    }
}
