import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `kingbreaker adds and bypasses block without spending it`(owner: BattleParticipant) throws {
        var context = try battle(["kingbreaker"], owner: owner)
        block(20, owner: .enemy, in: &context)
        try play(attack(.stun), owner: owner, in: &context)
        #expect(context.roster.enemy.currentHealth == 1970)
        #expect(blockAmount(.enemy, in: context) == 20)
        let meter = try #require(context.roster.enemy.activeEffects.first { $0.keyword == .stun })
        #expect(meter.effect.controlMeterValues?.amount == 30)
        try play(attack(), owner: owner, in: &context)
        #expect(context.roster.enemy.currentHealth == 1970)
        #expect(blockAmount(.enemy, in: context) == 10)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `everkeen repeats one critical packet without multiplying again`(owner: BattleParticipant) throws {
        var context = try battle(["everkeen"], owner: owner)
        block(5, owner: .enemy, in: &context)
        let first = try play(attack(), owner: owner, critical: true, in: &context)
        #expect(context.roster.enemy.currentHealth == 1965)
        #expect(first.filter { $0.abilityName == "Everkeen" }.map(\.amount) == [20])
        try play(attack(), owner: owner, critical: true, in: &context)
        #expect(context.roster.enemy.currentHealth == 1945)
        _ = UniqueCombatEngine.startTurn(in: &context)
        let next = try play(attack(), owner: owner, critical: true, in: &context)
        #expect(next.count(where: { $0.abilityName == "Everkeen" }) == 1)
        #expect(context.roster.enemy.currentHealth == 1905)
    }

    @Test func `everkeen uses outgoing damage before current defenses`() throws {
        var context = try battle(
            ["everkeen"],
            extra: CombatModifierProfile(damageDealtBonus: [.physical: 3]),
            enemyExtra: CombatModifierProfile(damageTakenFlat: [.physical: 2]),
        )
        let events = try play(attack(), critical: true, in: &context)
        #expect(events.first { $0.abilityName == "Everkeen" }?.amount == 24)
        #expect(context.roster.enemy.currentHealth == 1954)
    }

    @Test func `oathkeeper shares physical specific bonuses and counts generic bonus once`() throws {
        var extra = CombatModifierProfile(damageDealtBonus: [.physical: 3, .holy: 2])
        extra.triggers.damageVsBleedingBonus = 4
        extra.triggers.physicalDamageVsBleedingMultiplier = 2
        var context = try battle(["oathkeeper"], extra: extra)
        context.appendEffect(.bleed(1), to: context.roster.enemy.combatant, sourceID: context.roster.hero.id, remainingTurns: 2)
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1962)
        try play(attack(.burn), in: &context)
        #expect(context.roster.enemy.currentHealth == 1948)
    }

    @Test(arguments: [Keyword.burn, .bleed])
    func `bloodember shares bonuses on hits and ticks without baking twice`(keyword: Keyword) throws {
        var extra = CombatModifierProfile(damageDealtBonus: [.burn: 2, .bleed: 3], outgoingDamagePercent: 0.2)
        extra.triggers.damageVsBleedingBonus = 4
        var context = try battle(["bloodember_pendant"], extra: extra)
        context.appendEffect(.bleed(1), to: context.roster.enemy.combatant, sourceID: context.roster.hero.id, remainingTurns: 2)
        try play(attack(keyword), in: &context)
        #expect(context.roster.enemy.currentHealth == 1979)
        let tick = DoTDamage.resolveTurnDamage(
            basePotency: 10, keyword: keyword, target: context.roster.enemy.combatant,
            sourceActorID: context.roster.hero.id, in: &context,
        )
        #expect(tick.healthLost == 21)
        #expect(context.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 10 })
    }

    @Test func `bloodember keeps burn and bleed leech with bloodfire`() throws {
        var context = try battle(
            ["bloodember_pendant", "bloodfire_signet"],
            extra: CombatModifierProfile(damageDealtBonus: [.burn: 2, .bleed: 3]),
        )
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 100 }
        for keyword in [Keyword.burn, .bleed] {
            let before = context.roster.hero.currentHealth
            let outcome = DoTDamage.resolveTurnDamage(
                basePotency: 10, keyword: keyword, target: context.roster.enemy.combatant,
                sourceActorID: context.roster.hero.id, in: &context,
            )
            #expect(outcome.healthLost == 15)
            #expect(context.roster.hero.currentHealth - before == 8)
        }
    }

    @Test func `viper readiness survives reaction and pays typed followups once`() throws {
        var context = try battle(["vipers_courtesy"], extra: CombatModifierProfile(damageDealtBonus: [.poison: 2, .bleed: 3]))
        let actor = context.roster.hero.combatant
        _ = UniqueCombatEngine.afterDodge(by: actor, attackerID: context.roster.enemy.id, in: &context)
        _ = context.resolveDamage(DamageRequest(
            amount: 1,
            target: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: actor.id,
            options: .flatReaction,
        ))
        #expect(context.uniques.owners[.hero]?.viperReady == true)
        let before = context.roster.enemy.currentHealth
        try play(attack(.holy), in: &context)
        #expect(before - context.roster.enemy.currentHealth == 25)
        #expect(context.uniques.owners[.hero]?.viperReady == false)
        #expect(context.roster.enemy.activeEffects.contains { $0.effect == .poison(5) })
        #expect(context.roster.enemy.activeEffects.contains { $0.effect == .bleed(5) })
        try play(attack(), in: &context)
        #expect(before - context.roster.enemy.currentHealth == 35)
    }

    @Test func `wildheart readiness survives automatic play and makes all damage critical`() throws {
        var context = try battle(["wildhearts_favor", "everkeen"])
        let poison = Ability(
            id: "venom",
            name: "venom",
            tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .poison), DamageComponent(3, keyword: .bleed)],
            criticalChanceBonus: -1,
        )
        context.heroDeck = CombatDeck(abilities: [attack(id: "other"), poison])
        _ = UniqueCombatEngine.afterDodge(by: context.roster.hero.combatant, attackerID: context.roster.enemy.id, in: &context)
        #expect(context.hand.cards.map(\.ability.id) == ["venom"])
        context.isResolvingAutoPlayCard = true
        try play(poison, in: &context)
        context.isResolvingAutoPlayCard = false
        #expect(context.uniques.owners[.hero]?.wildheartReady == true)
        let before = context.roster.enemy.currentHealth
        let card = try #require(context.hand.cards.first { $0.ability.id == "venom" })
        let events = try context.playCard(cardID: card.id)
        #expect(before - context.roster.enemy.currentHealth == 22)
        let originalHits = events.filter { $0.kind == .abilityDamage && $0.abilityID == "venom" }
        let allCritical = originalHits.allSatisfy(\.isCritical)
        #expect(allCritical)
        #expect(context.uniques.owners[.hero]?.wildheartReady == false)
        #expect(events.count(where: { $0.abilityName == "Everkeen" }) == 1)
    }

    @Test func `serpent checks poison before each packet and retains other mitigation`() throws {
        var context = try battle(["serpents_eye"], enemyExtra: CombatModifierProfile(damageTakenFlat: [.physical: 2]))
        block(20, owner: .enemy, in: &context)
        let mixed = Ability(
            id: "mixed",
            name: "mixed",
            tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .poison), DamageComponent(10, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        try play(mixed, in: &context)
        #expect(blockAmount(.enemy, in: context) == 16)
        #expect(context.roster.enemy.currentHealth == 1992)
    }
}
