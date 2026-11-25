import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThematicItemAffixTests {
    @Test func `Blood Groove strengthens the opener and Red Temper caps the whole attack`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["blood_groove", "red_temper"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        let ability = Ability(id: "test_bleed_leech", name: "Bleed Leech", tier: .skill, damageComponents: [
            DamageComponent(8, keyword: .bleed, hasLeech: true),
            DamageComponent(8, keyword: .bleed, hasLeech: true),
        ], criticalChanceBonus: -1)
        let first = battle.performTestAction(ability)
        #expect(first.filter { $0.kind == .abilityDamage }.map(\.amount) == [9, 8])
        #expect(block(battle, owner: .hero) == 2)
        let second = battle.performTestAction(ability)
        #expect(second.filter { $0.kind == .abilityDamage }.map(\.amount) == [8, 8])
        #expect(block(battle, owner: .hero) == 4)
    }

    @Test func `Bell-Metal needs a fully Blocked hit and adds only buildup on the next Stun`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["bell_metal"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        _ = battle.resolveTestDamage(2, from: .enemy, to: .hero, options: hit)
        let first = battle.resolveTestDamage(2, keyword: .stun, options: hit)
        #expect(first.healthLost == 2)
        #expect(stunBuildup(battle) == 2)

        DefensePoolEngine.set(3, on: battle.hero, in: &battle)
        _ = battle.resolveTestDamage(2, from: .enemy, to: .hero, options: hit)
        let prepared = battle.resolveTestDamage(2, keyword: .stun, options: hit)
        #expect(prepared.healthLost == 2)
        #expect(stunBuildup(battle) == 6)
        _ = battle.resolveTestDamage(2, keyword: .stun, options: hit)
        #expect(stunBuildup(battle) == 8)
    }

    @Test func `Tolltaker bypasses Block while first theft alone grants ally Block`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["tolltaker", "smugglers_lining"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = battle.recordingEvents { context in
            _ = await context.grantGold(1, to: context.hero, abilityName: "Gain Gold")
        }
        #expect(block(battle, owner: .companion) == 0)
        _ = battle.recordingEvents { context in
            for _ in 0 ..< 2 {
                _ = await context.grantGold(1, to: context.hero, abilityName: "Steal", isTheft: true)
            }
        }
        #expect(block(battle, owner: .companion) == 4)
        DefensePoolEngine.set(5, on: battle.enemy, in: &battle)
        let first = battle.resolveTestDamage(5, options: hit)
        #expect(first.healthLost == 2)
        #expect(block(battle, owner: .enemy) == 2)
        let second = battle.resolveTestDamage(2, options: hit)
        #expect(second.healthLost == 0)
        #expect(block(battle, owner: .enemy) == 0)
    }

    @Test func `Verdigris strips remaining Block once per turn on the wearer's ally hit`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["verdigris"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.poison(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        DefensePoolEngine.set(8, on: battle.enemy, in: &battle)
        _ = battle.resolveTestDamage(1, options: hit)
        #expect(block(battle, owner: .enemy) == 7)
        _ = battle.resolveTestDamage(1, from: .companion, options: hit)
        #expect(block(battle, owner: .enemy) == 4)
        _ = battle.resolveTestDamage(1, from: .companion, options: hit)
        #expect(block(battle, owner: .enemy) == 3)
    }

    @Test func `Banked Ember preserves the first Burn tick and Red Thread pays on natural expiry`() throws {
        let modifiers = try profile(["banked_ember", "red_thread"])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: modifiers, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 3
        _ = battle.recordingEvents { context in
            await context.applyDecayingDoT(
                keyword: .burn, potency: 6, to: context.enemy, sourceActorID: context.hero.id, application: .afterHit,
            )
            _ = context.insertEffect(.bleed(2), to: context.enemy, sourceID: context.hero.id, remainingTurns: 2)
        }
        for (burn, health) in [(4, 3), (2, 3 + modifiers.triggers.finalBleedTickAllyHeal)] {
            _ = battle.recordingEvents { await EffectTurnEngine.advanceEffects(on: $0.enemy, context: &$0) }
            #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.keyword == .burn }?.effect.potency == burn)
            #expect(battle.roster.companion.currentHealth == health)
        }
    }

    @Test func `Ally support refreshes Dodge and real card healing grants Thorns and prepares Holy damage`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["side_laced", "thornstitch", "votive"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 5
        let heal = Ability(id: "test_ally_heal", name: "Ally Heal", tier: .basic, targetedEffects: [
            TargetedEffect(.instantHeal(.health, 1), target: .companion),
        ], criticalChanceBonus: -1)
        for _ in 0 ..< 2 {
            let card = BattleCardCombatEngine.deal(heal, owner: .hero, context: &battle)
            _ = try battle.playCard(cardID: card.id)
        }
        #expect(battle.roster.hero.talents.dodgeChanceBonus(atTurn: battle.turnCount) == 0.10)
        #expect(battle.activeEffects(of: battle.companion).first { $0.effect.keyword == .thorns }?.effect.potency == 2)
        #expect(battle.resolveTestDamage(2, keyword: .holy, options: hit).healthLost == 4)

        battle.roster.hero.talents.beginTurn(battle.turnCount + 1)
        #expect(battle.resolveTestDamage(2, keyword: .holy, options: hit).healthLost == 2)
        #expect(battle.roster.hero.talents.dodgeChanceBonus(atTurn: battle.turnCount + 1) == 0)
    }

    @Test func `Rimeglass discounts one Freeze purchase and Deepwell requires full Mana`() throws {
        var battle = try BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40, maxMana: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroMana: 10, heroModifiers: profile(["rimeglass", "deepwell"]), appliesFightPacing: false,
        )
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        DefensePoolEngine.decayBlock(on: battle.hero, in: &battle)
        #expect(block(battle, owner: .hero) == 6)

        battle.turnCadence.freezeCardsPlayed[.companion] = 1
        let freeze = Ability(id: "test_freeze", name: "Freeze", tier: .basic, directDamage: 1, damageKeyword: .freeze)
        battle.performTestAction(freeze)
        #expect(battle.roster.hero.currentMana == 8)
        battle.performTestAction(freeze)
        #expect(battle.roster.hero.currentMana == 5)
        DefensePoolEngine.decayBlock(on: battle.hero, in: &battle)
        #expect(block(battle, owner: .hero) == 3)
    }

    @Test func `Vigil Bell credits the Stun completer and draws only when the action is skipped`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [Ability(id: "test_strike", name: "Strike", tier: .basic, directDamage: 1)],
            companionModifiers: profile(["vigil_bell"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = battle.chargeTestControl(1, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id)
        let completed = battle.chargeTestControl(80, keyword: .stun, to: battle.enemy, sourceActorID: battle.companion.id)
        #expect(!completed.contains { $0.abilityName == "Vigil Bell" })
        let skipped = battle.recordingEvents { await BattleTurnEngine.consumeActionSkip(for: $0.enemy, context: &$0) }
        let draw = try #require(skipped.first { $0.abilityName == "Vigil Bell" })
        #expect(draw.actorID == battle.companion.id)
        #expect(draw.targetID == battle.hero.id)
        #expect(draw.amount == 1)
    }

    private var hit: DamageOperation {
        .attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
    }

    private func profile(_ ids: [String]) throws -> CombatModifierProfile {
        var result = CombatModifierProfile.zero
        result.triggers.criticalChanceBonus = -1
        for id in ids {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &result, abilityName: affix.title)
        }
        return result
    }

    private func block(_ battle: BattleState, owner: BattleParticipant) -> Int {
        DefensePoolEngine.blockPoints(in: battle.roster[owner].activeEffects)
    }

    private func stunBuildup(_ battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first { $0.effect.keyword == .stun }?.effect.controlMeterValues?.amount
    }
}
