import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct QuietItemAffixTests {
    @Test func `Relay refreshes without feedback and Prismatic compares whole attacks per wearer`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["relay", "prismatic"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        let physical = attack(.physical)
        let holy = attack(.holy)
        _ = try play(physical, owner: .hero, in: &battle)
        let switched = try play(holy, owner: .hero, in: &battle)
        #expect(switched.filter { $0.kind == .abilityDamage }.map(\.amount) == [6, 6])
        let repeated = try play(holy, owner: .hero, in: &battle)
        #expect(repeated.filter { $0.kind == .abilityDamage }.map(\.amount) == [4, 4])
        let relayed = try play(physical, owner: .companion, in: &battle)
        #expect(relayed.filter { $0.kind == .abilityDamage }.map(\.amount) == [6, 4])
        let ordinary = try play(physical, owner: .companion, in: &battle)
        #expect(ordinary.filter { $0.kind == .abilityDamage }.map(\.amount) == [4, 4])
        for events in [switched, repeated, relayed, ordinary] {
            #expect(events.count(where: { $0.kind == .abilityDamage }) == 2)
            #expect(!events.contains { $0.abilityName == "Relay" || $0.abilityName == "Prismatic" })
        }
    }

    @Test func `Breakthrough boosts only overflow from an attack that exhausts Block`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["breakthrough"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        let hit = Ability(id: "overflow", name: "Overflow", tier: .basic, directDamage: 20)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let broken = battle.performTestAction(hit)
        #expect(broken.first { $0.kind == .abilityDamage }?.amount == 12)
        #expect(broken.count(where: { $0.kind == .abilityDamage }) == 1)
        let unblocked = battle.performTestAction(hit)
        #expect(unblocked.first { $0.kind == .abilityDamage }?.amount == 20)
        DefensePoolEngine.set(40, on: battle.enemy, in: &battle)
        let blocked = battle.performTestAction(hit)
        #expect(blocked.first { $0.kind == .abilityDamage }?.amount == 0)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let tick = battle.resolveTestDamage(20, options: .periodic)
        #expect(tick.healthLost == 10)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let repeatHit = battle.resolveTestDamage(20, options: .attack(origin: .repeatedAttack, scaling: .resolved))
        #expect(repeatHit.healthLost == 12)
    }

    @Test func `Steelsong refreshes and waits through resolved Block while Mutual changes the same gain`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["steelsong", "mutual"]), dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = try play(attack(.physical), owner: .hero, in: &battle)
        _ = try play(attack(.physical), owner: .hero, in: &battle)
        DefensePoolEngine.set(5, on: battle.companion, in: &battle)
        #expect(battle.applyBlockGain(10, to: battle.hero, source: battle.hero, abilityName: "Transfer", amountBasis: .resolved) == 10)
        let first = battle.recordingResult { context in
            #expect(context.applyBlockGain(20, to: context.hero, source: context.hero, abilityName: "Guard") == 25)
        }
        #expect(first.events.count(where: { $0.effectKind == .shieldApplied }) == 1)
        #expect(!first.events.contains { $0.abilityName == "Steelsong" || $0.abilityName == "Mutual" })
        #expect(battle.applyBlockGain(20, to: battle.hero, source: battle.hero, abilityName: "Guard") == 23)
    }

    @Test func `Conditional affixes modify existing attack and healing results without amplifying ticks`() throws {
        var battle = try BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile(["measured", "catalytic", "discerning", "unburdened", "merciful"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 5
        DefensePoolEngine.set(5, on: battle.enemy, in: &battle)
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let hit = Ability(id: "conditional", name: "Conditional", tier: .basic, directDamage: 20)
        let events = battle.performTestAction(hit)
        // (20 + 2 Measured + 3 Catalytic + 4 Discerning) * 1.08, less 5 Block.
        #expect(events.first { $0.kind == .abilityDamage }?.amount == 26)
        let before = battle.health(of: battle.enemy)
        let tick = battle.resolveTestDamage(2, options: .periodic)
        #expect(tick.healthLost == 2)
        #expect(battle.health(of: battle.enemy) == before - 2)
        _ = battle.chargeTestControl(30, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        let heal = battle.performTestAction(Ability(
            id: "mend",
            name: "Mend",
            tier: .basic,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 2), target: .actor)],
        ))
        #expect(heal.first { $0.effectKind == .instantHeal }?.amount == 4)
        #expect(heal.count(where: { $0.effectKind == .instantHeal }) == 1)
    }

    private func attack(_ keyword: Keyword) -> Ability {
        Ability(id: "quiet_\(keyword.rawValue)", name: "Quiet Attack", tier: .basic, damageComponents: [
            DamageComponent(4, keyword: keyword), DamageComponent(4, keyword: keyword),
        ], criticalChanceBonus: -1)
    }

    private func play(_ ability: Ability, owner: BattleParticipant, in battle: inout BattleState) throws -> [ActionEvent] {
        battle.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &battle)
        return try battle.playCard(cardID: card.id).events
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
}
