import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AshenVitalityActionPreparationTests {
    @Test func `overhealing reserves Ashen Vitality for a later ability`() {
        var battle = makeBattle()
        let actor = battle.companion
        let target = battle.enemy
        let creatingAbility = Ability(
            id: "restoration-and-burn", name: "Restoration and Burn", tier: .skill,
            operations: [
                .effect(TargetedEffect(.instantHeal(.health, 3), target: .actor)),
                .damage(DamageComponent(3, keyword: .burn)),
            ],
        )

        let events = BattleTurnEngine.performAction(
            ability: creatingAbility, actor: actor, abilityTarget: target, context: &battle,
        )

        #expect(events.contains { $0.kind == .overheal && $0.targetID == actor.id && $0.amount == 3 })
        #expect(events.filter { $0.kind == .abilityDamage && $0.keyword == .burn }.map(\.amount) == [3])
        #expect(battle.roster.companion.talents.pending.nextBurnDamageBonus?.value == 2)
        expectLaterBurnConsumesPreparation(actor: actor, target: target, in: &battle)
    }

    @Test func `Burn Leech counterattack cannot spend its own overhealing preparation`() {
        let basic = Ability(
            id: "two-burn-hits", name: "Two Burn Hits", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn), DamageComponent(4, keyword: .burn)],
            hasLeech: true,
        )
        var battle = makeBattle(basic: basic, countersAfterDodge: true)
        let actor = battle.companion
        let target = battle.enemy
        battle.appendEffect(.evadeNextHit, to: actor, sourceID: actor.id, remainingTurns: 0)

        let result = battle.resolveDamage(DamageRequest(
            amount: 3, target: actor, keyword: .physical, sourceActorID: target.id,
            options: .attack(tier: .basic, abilityCriticalChanceBonus: -1),
        ))

        #expect(result.flags.contains(.dodged))
        #expect(result.events.filter { $0.kind == .abilityDamage && $0.abilityID == basic.id }.map(\.amount) == [4, 4])
        #expect(result.events.count { $0.kind == .overheal && $0.targetID == actor.id } == 2)
        #expect(battle.roster.companion.talents.pending.nextBurnDamageBonus?.value == 2)
        expectLaterBurnConsumesPreparation(actor: actor, target: target, in: &battle)
    }

    private func makeBattle(basic: Ability = .fireArrow, countersAfterDodge: Bool = false) -> BattleState {
        var profile = CombatantTalentCatalog.profile(for: ["phoenix_health_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onDodgeCounterBasicAttack = countersAfterDodge
        var battle = BattleStateTestFactory.makeBattle(
            companion: CombatantFixtures.passiveCompanion(abilities: [basic]),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: profile,
            enemyModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(dodgeChanceBonus: -1),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    private func expectLaterBurnConsumesPreparation(actor: Combatant, target: Combatant, in battle: inout BattleState) {
        let events = BattleTurnEngine.performAction(
            ability: .fireArrow, actor: actor, abilityTarget: target, context: &battle,
        )
        #expect(events.filter { $0.kind == .abilityDamage && $0.keyword == .burn }.map(\.amount) == [4])
        #expect(battle.roster.companion.talents.pending.nextBurnDamageBonus == nil)
    }
}
