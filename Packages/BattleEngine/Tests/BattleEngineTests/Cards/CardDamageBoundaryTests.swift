import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CardDamageBoundaryTests {
    @Test(arguments: [Int.max, Int.max / 2])
    func `large Kindled preparation resolves a doubled Burn card and its costs and rewards`(bonus: Int) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        let hero = battle.hero
        _ = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(1), source: hero, target: hero, battle: &battle,
        )
        _ = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(bonus), source: hero, target: hero, battle: &battle,
        )
        battle.appendEffect(.nextStrikeDouble, to: hero, sourceID: hero.id, remainingTurns: 0)
        DefensePoolEngine.set(4, on: hero, in: &battle)
        let ability = Ability(
            id: "prepared-burn-boundary", name: "Prepared Burn", tier: .basic,
            damageComponents: [DamageComponent(1, target: .actor), DamageComponent(2, keyword: .burn)],
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
            criticalChanceBonus: -1, blockCost: 2,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id).events

        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: hero) == 19)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: hero)) == 2)
        #expect(battle.gold == 2)
        #expect(events.filter { $0.kind == .abilityDamage && $0.targetID == hero.id }.map(\.amount) == [1])
        #expect(!battle.activeEffects(of: hero).contains {
            $0.effect.kind == .nextBurnBonus || $0.effect.kind == .nextStrikeDouble
        })
    }

    @Test func `legacy Steam Explosion saturates consumed Burn added to a Freeze card`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .init(triggers: .init(dot: DotTriggers(steamExplosion: true))),
            dealOpeningHand: false,
        )
        battle.appendEffect(.burn(Int.max), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let ability = Ability(
            id: "steam-preparation-boundary", name: "Freeze", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .freeze)],
        )

        let prepared = prepareTalentCard(ability, in: &battle)

        #expect(prepared.damageComponents.map(\.amount) == [Int.max])
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .burn })
    }

    @Test(arguments: [false, true])
    func `Poison card amplification saturates damage and attached effects`(sealedVial: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .init(triggers: .init(dot: DotTriggers(sealedVial: sealedVial))),
            dealOpeningHand: false,
        )
        if !sealedVial {
            battle.roster.mutateRuntime(for: battle.hero) { $0.talents.history.preparations.insert(.doublePoison) }
        }
        let ability = Ability(
            id: "poison-preparation-boundary", name: "Poison", tier: .basic,
            damageComponents: [
                DamageComponent(Int.max, keyword: .poison, bonusAmount: Int.max),
                DamageComponent(3, keyword: .poison),
                DamageComponent(3, keyword: .poison, target: .actor),
            ],
            targetedEffects: [
                TargetedEffect(.poison(Int.max)),
                TargetedEffect(.recurringDamage(.poison, Int.max, 2)),
                TargetedEffect(.poison(Int.max), target: .actor),
            ],
        )

        let prepared = prepareTalentCard(ability, in: &battle)

        #expect(prepared.damageComponents == [
            DamageComponent(Int.max, keyword: .poison, bonusAmount: Int.max),
            DamageComponent(6, keyword: .poison),
            DamageComponent(3, keyword: .poison, target: .actor),
        ])
        #expect(prepared.targetedEffects == ability.targetedEffects)
        #expect(battle.roster.combatant(for: battle.hero.id)?.talents.history.preparations.contains(.doublePoison) != true)
    }

    private func prepareTalentCard(_ ability: Ability, in battle: inout BattleState) -> Ability {
        let actor = battle.hero
        let action = BattleActionContext(actor: actor, in: battle)
        let facts = ResolvedActionFacts(original: ability, resolved: ability, action: action, origin: .card, in: battle)
        let cardID = battle.resolution.beginCard(actorID: actor.id)
        _ = battle.resolution.beginAction(action, origin: .card)
        defer {
            battle.resolution.endAction()
            battle.resolution.endCard(cardID)
        }
        _ = battle.resolution.prepareAction(facts)
        return BattleTurnEngine.prepareTalentAction(ability: ability, actor: actor, in: &battle)
    }
}
