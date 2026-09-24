import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Red Harvest detonates Bleed only after damaging Physical Critical Hits`(owner: BattleParticipant) throws {
        func prepared() throws -> BattleState {
            var context = try battle(["red_harvest"], owner: owner)
            context.appendEffect(
                .bleed(4), to: context.roster.enemy.combatant,
                sourceID: context.roster[owner].id, remainingTurns: 2,
            )
            return context
        }

        var critical = try prepared()
        let enemy = critical.roster.enemy.combatant
        let beforeHealth = critical.roster.enemy.currentHealth
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &critical)
        #expect(!critical.roster.hasAffliction(.bleed, on: enemy))
        #expect(beforeHealth - critical.roster.enemy.currentHealth > 10)
        #expect(critical.hand.isEmpty)
        critical.appendEffect(.bleed(4), to: enemy, sourceID: critical.roster[owner].id, remainingTurns: 2)
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &critical)
        #expect(!critical.roster.hasAffliction(.bleed, on: enemy))

        var ordinary = try prepared()
        try play(attack(.physical, amount: 5), owner: owner, in: &ordinary)
        #expect(ordinary.roster.hasAffliction(.bleed, on: enemy))

        var blocked = try prepared()
        block(100, owner: .enemy, in: &blocked)
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &blocked)
        #expect(blocked.roster.hasAffliction(.bleed, on: enemy))
    }

    @Test func `Physical Crits repeatedly draw from the Companion deck`() throws {
        var context = try battle(["huntsmasters_call"])
        context.companionDeck = CombatDeck(abilities: [attack(id: "companion-a"), attack(id: "companion-b")])

        try play(attack(.physical, id: "ordinary"), in: &context)
        #expect(context.hand.isEmpty)
        #expect(context.companionDeck.count == 2)

        let first = try play(attack(.physical, id: "critical-a"), critical: true, in: &context)
        #expect(first.contains { $0.abilityName == "Huntsmaster’s Call" && $0.effectKind == .cardsDrawn })
        #expect(context.hand.cards.count { $0.owner == .companion } == 1)

        try play(attack(.physical, id: "critical-b"), critical: true, in: &context)
        #expect(context.hand.cards.count { $0.owner == .companion } == 2)
        #expect(context.companionDeck.isEmpty)

        var other = try battle(["huntsmasters_call"], owner: .companion)
        other.companionDeck = CombatDeck(abilities: [attack(id: "not-drawn")])
        try play(attack(.physical), owner: .companion, critical: true, in: &other)
        #expect(other.hand.isEmpty)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Threefold restores its wearer Mana from either party member's elemental damage`(owner: BattleParticipant) throws {
        var bonus = CombatModifierProfile.zero
        bonus.triggers.threefoldElementalDamageManaChancePercent = 0.90
        var context = try battle(["threefold_grace"], owner: owner, extra: bonus)
        let attacker: BattleParticipant = owner == .hero ? .companion : .hero
        let target = context.roster.enemy.combatant

        for keyword in [Keyword.burn, .freeze, .holy] {
            _ = context.resolveDamage(DamageRequest(
                amount: 5, target: target, keyword: keyword,
                sourceActorID: context.roster[attacker].id,
                options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            ))
        }
        #expect(context.roster[owner].currentMana == 3)
        #expect(context.roster[attacker].currentMana == 0)

        _ = context.resolveDamage(DamageRequest(
            amount: 5, target: target, keyword: .physical,
            sourceActorID: context.roster[attacker].id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(context.roster[owner].currentMana == 3)
    }

    @Test func `Golden Verdict's Holy Stun pays Gold theft bonuses`() throws {
        var bonus = CombatModifierProfile.zero
        bonus.triggers.goldStealFlatBonus = 2
        var context = try battle(["golden_verdict"], extra: bonus)
        let target = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: target, in: context)

        let outcome = context.resolveDamage(DamageRequest(
            amount: threshold, target: target, keyword: .holy,
            sourceActorID: context.roster.hero.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(context.roster.hasControlStatus(for: target, keyword: .stun))
        #expect(context.gold == 3)
        #expect(outcome.events.contains { $0.abilityName == "Golden Verdict" && $0.keyword == .gold })
    }
}
