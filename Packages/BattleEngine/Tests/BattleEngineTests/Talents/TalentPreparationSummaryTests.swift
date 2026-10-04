import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct TalentPreparationSummaryTests {
    @Test(arguments: ["panther_bleed_t4_2", "shield_scarab_stun_t3_1", "wildcard_physical_t3_2", "shield_scarab_block_t3_2"])
    func `earned damage preparations appear in details until consumed`(talentID: String) throws {
        let fixtures = UniqueCollectionTests()
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        var context = try fixtures.battle([], owner: .companion, extra: profile)
        let actor = context.companion
        let keyword: Keyword
        switch talentID {
        case "panther_bleed_t4_2":
            keyword = .bleed
            _ = fixtures.enemyHit(101, target: .companion, in: &context)
        case "wildcard_physical_t3_2":
            keyword = .physical
            fixtures.block(10, owner: .enemy, in: &context)
            try fixtures.play(fixtures.attack(), owner: .companion, in: &context)
        default:
            keyword = talentID == "shield_scarab_stun_t3_1" ? .stun : .holy
            fixtures.block(1, owner: .companion, in: &context)
            _ = fixtures.enemyHit(2, target: .companion, in: &context)
        }

        #expect(hasPreparation(keyword, for: actor, in: context))
        let before = context.roster.enemy.currentHealth
        try fixtures.play(fixtures.attack(keyword), owner: .companion, in: &context)
        #expect(before - context.roster.enemy.currentHealth == 20)
        #expect(!hasPreparation(keyword, for: actor, in: context))
    }

    @Test(arguments: [
        "frost_whelp_dodge_t4_1", "panther_dodge_t2_2", "wolf_dodge_t1_2", "wolf_dodge_t4_1", "fox_dodge_t4_1",
    ])
    func `dodge preparations appear in details until the qualifying attack`(talentID: String) throws {
        let fixtures = UniqueCollectionTests()
        var context = try fixtures.battle([], owner: .companion, extra: CombatantTalentCatalog.profile(for: [talentID]))
        let actor = context.companion
        context.appendEffect(.evadeNextHit, to: actor, sourceID: actor.id, remainingTurns: 0)
        let hit = context.resolveDamage(DamageRequest(
            amount: 1, target: actor, keyword: .physical,
            sourceActorID: context.enemy.id, options: .attack(),
        ))
        #expect(hit.isDodged)
        let keyword: Keyword = switch talentID {
        case "frost_whelp_dodge_t4_1": .freeze
        case "wolf_dodge_t1_2": .bleed
        default: .physical
        }

        #expect(hasPreparation(keyword, for: actor, in: context))
        try fixtures.play(
            fixtures.attack(keyword), owner: .companion,
            critical: talentID == "fox_dodge_t4_1", in: &context,
        )
        #expect(!hasPreparation(keyword, for: actor, in: context))
    }

    @Test(arguments: ["fox_stun_t4_1", "mana_moth_mana_t2_2"])
    func `stun and Mana rewards expose their next attack preparation`(talentID: String) throws {
        let fixtures = UniqueCollectionTests()
        var context = try fixtures.battle([], owner: .companion, extra: CombatantTalentCatalog.profile(for: [talentID]))
        let actor = context.companion
        if talentID == "fox_stun_t4_1" {
            _ = CombatTriggerEngine.afterEnemyStunned(sourceActorID: actor.id, in: &context)
        } else {
            _ = context.restoreManaEmitting(1, to: actor, abilityName: "Restore Mana")
            let payment = context.payMana(1, for: actor)
            _ = CombatTriggerEngine.afterSpendMana(payment, in: &context)
        }

        #expect(hasPreparation(.physical, for: actor, in: context))
        let before = context.roster.enemy.currentHealth
        try fixtures.play(fixtures.attack(), owner: .companion, in: &context)
        #expect(before - context.roster.enemy.currentHealth == (talentID == "fox_stun_t4_1" ? 20 : 12))
        #expect(!hasPreparation(.physical, for: actor, in: context))
    }

    @Test(arguments: [Effect.burn(2), .controlMeter(.freeze, 5, 10)])
    func `Lesson Learned details follow protected keywords until immunity expires`(effect: Effect) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_cleanse_t4_1")
        var battle = BattleStateTestFactory.makeBattle(
            companion: owl.combatant, companionModifiers: owl.modifiers, dealOpeningHand: false,
        )
        battle.appendEffect(effect, to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        _ = EffectRemovalOperation.resolveCleanse(
            .all(nil), source: battle.companion, target: battle.hero, abilityName: "Cleanse", in: &battle,
        )

        #expect(battle.effectSummaries(of: battle.hero).contains { $0.keyword == effect.keyword })
        let firstAppendSucceeded = battle.appendEffect(effect, to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        #expect(!firstAppendSucceeded)

        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)

        #expect(!battle.effectSummaries(of: battle.hero).contains { $0.keyword == effect.keyword })
        let secondAppendSucceeded = battle.appendEffect(effect, to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        #expect(secondAppendSucceeded)
    }

    @Test(arguments: [
        (Effect.shield(.block, 6), "Block"), (.thorns(3), "Thorns"),
        (.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), "Avatar"),
    ])
    func `Interdict details name the buff that cannot return until protection expires`(effect: Effect, name: String) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_holy_t4_1")
        var battle = BattleStateTestFactory.makeBattle(
            companion: owl.combatant, companionModifiers: owl.modifiers, dealOpeningHand: false,
        )
        battle.appendEffect(effect, to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 2)
        _ = EffectRemovalOperation.resolvePurge(
            .all(nil), source: battle.companion, target: battle.enemy, abilityName: "Purge", in: &battle,
        )

        #expect(battle.effectSummaries(of: battle.enemy).contains { $0.keyword == .purge && $0.text.contains(name) })
        let firstPurgeAppendSucceeded = battle.appendEffect(effect, to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 2)
        #expect(!firstPurgeAppendSucceeded)

        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)

        #expect(!battle.effectSummaries(of: battle.enemy).contains { $0.keyword == .purge })
        let secondPurgeAppendSucceeded = battle.appendEffect(effect, to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 2)
        #expect(secondPurgeAppendSucceeded)
    }

    private func hasPreparation(_ keyword: Keyword, for actor: Combatant, in context: BattleState) -> Bool {
        context.effectSummaries(of: actor).contains { $0.keyword == keyword && $0.text.contains("next") }
    }
}
