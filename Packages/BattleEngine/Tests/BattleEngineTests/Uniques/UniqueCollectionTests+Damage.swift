import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [Keyword.burn, .bleed], [false, true])
    func `bloodfire followups deal one damage and stop at the chain limit`(keyword: Keyword, chained: Bool) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.burnProcsBleedChancePercent = keyword == .burn || chained ? 1 : 0
        profile.triggers.bleedProcsBurnChancePercent = keyword == .bleed || chained ? 1 : 0
        var context = try battle([], extra: profile)
        let enemy = context.roster.enemy.combatant
        let before = context.roster.enemy.currentHealth
        let effect: Effect = keyword == .burn ? .burn(20) : .bleed(10)
        context.appendEffect(effect, to: enemy, sourceID: context.roster.hero.id, remainingTurns: 2)
        let active = try #require(context.roster.enemy.activeEffects.first)
        let handler = try #require(EffectHandlers.all[effect.kind])

        let events = handler.advanceTurn(active, on: enemy, in: &context)

        let followups = chained ? DoTMirrorCascade.maxChainDepth : 1
        #expect(before - context.roster.enemy.currentHealth == 10 + followups)
        #expect(events.filter { $0.kind == .status }.map(\.amount) == Array(repeating: 1, count: followups) + [10])
        #expect(context.resolution.depth(.dotMirror) == 0)
    }

    @Test(arguments: [Keyword.burn, .bleed], [false, true])
    func `bloodfire reacts to direct damage and standalone ticks`(keyword: Keyword, periodic: Bool) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.burnProcsBleedChancePercent = keyword == .burn ? 1 : 0
        profile.triggers.bleedProcsBurnChancePercent = keyword == .bleed ? 1 : 0
        var context = try battle([], extra: profile)
        let before = context.roster.enemy.currentHealth
        let options: DamageOperation = periodic ? .periodic : .attack(
            accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        )

        let outcome = context.resolveDamage(DamageRequest(
            amount: 10, target: context.roster.enemy.combatant, keyword: keyword,
            sourceActorID: context.roster.hero.id, options: options,
        ))

        #expect(outcome.healthLost == 10)
        #expect(before - context.roster.enemy.currentHealth == 11)
        #expect(outcome.events.filter { $0.kind == .status }.map(\.amount) == [1])
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `wardbreaker only purges when its wearer causes the stun`(source: BattleParticipant) throws {
        var context = try battle(["wardbreaker"])
        let enemy = context.roster.enemy.combatant
        context.appendEffect(.thorns(3), to: enemy, sourceID: enemy.id, remainingTurns: 0)
        let threshold = ControlMeterEngine.threshold(for: enemy, in: context)

        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: enemy, sourceActorID: context.roster[source].id,
            applyFightPacing: false, in: &context,
        )

        #expect(context.roster.hasControlStatus(for: enemy, keyword: .stun))
        #expect(context.roster.enemy.activeEffects.contains { $0.effect == .thorns(3) } == (source == .companion))
        #expect(context.roster.enemy.currentHealth == (source == .hero ? 1998 : 2000))
    }

    @Test(arguments: ["everkeen", "huntsmasters_call"])
    func `critical hit rewards trigger when block absorbs the whole hit`(item: String) throws {
        var context = try battle([item])
        block(20, owner: .enemy, in: &context)
        let events = try play(attack(), critical: true, in: &context)
        #expect(blockAmount(.enemy, in: context) == 0)
        #expect(context.roster.enemy.currentHealth < 2000)
        if item == "everkeen" {
            #expect(events.contains { $0.abilityName == "Everkeen" && $0.amount == 20 })
        } else {
            #expect(events.contains { $0.kind == .ability && $0.abilityID == context.companion.abilityLoadout.basic?.id })
        }
        let next = try play(attack(), critical: true, in: &context)
        #expect(!next.contains { $0.abilityName == "Everkeen" })
        #expect(!next.contains { $0.kind == .ability && $0.actorID == context.companion.id })
    }

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
        let tick = DoTDamage.resolveDamage(
            basePotency: 10, keyword: keyword, target: context.roster.enemy.combatant,
            sourceActorID: context.roster.hero.id, in: &context,
        )
        #expect(tick.healthLost == 21)
        #expect(context.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 10 })
    }

    @Test func `bloodember keeps burn and bleed leech with bloodfire`() throws {
        var extra = CombatModifierProfile(damageDealtBonus: [.burn: 2, .bleed: 3])
        extra.triggers.criticalChanceBonus = -1
        var context = try battle(
            ["bloodember_pendant", "bloodfire_signet"],
            extra: extra,
        )
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 100 }
        for keyword in [Keyword.burn, .bleed] {
            let before = context.roster.hero.currentHealth
            let outcome = DoTDamage.resolveDamage(
                basePotency: 10, keyword: keyword, target: context.roster.enemy.combatant,
                sourceActorID: context.roster.hero.id, in: &context,
            )
            #expect(outcome.healthLost == 15)
            let expectedHealing = outcome.events.filter { $0.kind == .status }.reduce(0) {
                $0 + CombatRounding.scaled($1.amount, multiplier: 0.5)
            }
            #expect(context.roster.hero.currentHealth - before == expectedHealing)
        }
    }

    @Test func `viper readiness survives reaction and pays typed followups once`() throws {
        var context = try battle(["vipers_courtesy"], extra: CombatModifierProfile(damageDealtBonus: [.poison: 2, .bleed: 3]))
        let actor = context.roster.hero.combatant
        _ = UniqueCombatEngine.afterUniqueDodge(by: actor, attackerID: context.roster.enemy.id, in: &context)
        _ = context.resolveDamage(DamageRequest(
            amount: 1,
            target: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: actor.id,
            options: .reaction(),
        ))
        #expect(context.uniques.owners[.hero]?.viperReady == true)
        block(10, owner: .enemy, in: &context)
        try play(attack(.holy), in: &context)
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
        _ = UniqueCombatEngine.afterUniqueDodge(by: context.roster.hero.combatant, attackerID: context.roster.enemy.id, in: &context)
        #expect(context.hand.cards.map(\.ability.id) == ["venom"])
        _ = try context.withAutomaticPlay { context in try play(poison, in: &context) }
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
