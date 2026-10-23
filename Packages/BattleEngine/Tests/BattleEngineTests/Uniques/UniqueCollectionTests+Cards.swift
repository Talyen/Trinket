import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `wrenflight counts only wearers ordinary cards`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight"], owner: owner)
        let other: BattleParticipant = owner == .hero ? .companion : .hero
        let draw = attack(id: "drawn")
        if owner == .hero {
            context.heroDeck = CombatDeck(abilities: [draw])
        } else {
            context.companionDeck = CombatDeck(abilities: [draw])
        }
        try play(attack(id: "first"), owner: owner, in: &context)
        try play(attack(id: "other"), owner: other, in: &context)
        let second = try play(attack(id: "second"), owner: owner, in: &context)
        #expect(second.contains { $0.abilityName == "Wrenflight" && $0.effectKind == .cardsDrawn })
        #expect(context.roster[owner].uniques.wrenflightDodge == 0.1)
        _ = try context.withAutomaticPlay { context in
            try play(attack(id: "automatic"), owner: owner, in: &context)
        }
        // Automatic plays do not advance the wearer's ordinary card count.
        try #expect(context.roster[owner].uniques.cardsPlayed == 2)
        UniqueCombatEngine.startTurn(in: &context)
        #expect(context.roster[owner].uniques.wrenflightDodge == 0)
        #expect(context.roster[owner].uniques.cardsPlayed == 0)
        // The Returning Gale third-card rule is retired; Dodge-triggered returns are covered
        // by ReturningGaleRegressionTests (ordinary vs automatic, non-damaging, FIFO, no duplicates).
    }

    // The Returning Flight turn-start recovery rule is retired (replaced by immediate
    // first-Physical return). Coverage survives in ReturningGaleRegressionTests
    // (`flight returns first physical once and moves without deck cycle`,
    // `gale and flight together do not duplicate`).

    @Test(
        arguments: [
            CombatantFixtures.deterministicBattleSeed,
            CombatantFixtures.deterministicBattleSeedVariant(1),
        ],
        [false, true],
    )
    func `cinderbloom uses its resolved element for Wildheart`(seed: UInt64, automatic: Bool) throws {
        var context = try battle(["wildhearts_favor"])
        context.rng = SeededRandomNumberGenerator(seed: seed)
        context.roster[.hero].uniques.wildheartReady = true
        let events: [ActionEvent] = if automatic {
            try context.withAutomaticPlay { context in try play(.cinderbloom, in: &context) }
        } else {
            try play(.cinderbloom, in: &context)
        }
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.abilityID == "cinderbloom" })
        #expect(context.roster[.hero].uniques.wildheartReady == (automatic || hit.keyword != .poison))
        if !automatic {
            #expect(hit.isCritical == (hit.keyword == .poison))
        }
    }

    @Test func `draw and play does not spend unique card allowances`() throws {
        var context = try battle(["wrenflight", "the_returning_gale"])
        context.heroDeck = CombatDeck(abilities: [attack(.holy, id: "auto")])
        let ability = Ability(id: "draw", name: "draw", tier: .basic, effects: [.drawAndPlayCards(1)])
        try play(ability, in: &context)
        #expect(context.roster[.hero].uniques.cardsPlayed == 1)
        #expect(context.hand.isEmpty)
    }

    @Test func `Paid in Full cannot strengthen the later hit that triggered its theft`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t4_1"])
        let preparedDamage = profile.triggers.goldStealNextAttackBonus
        profile.triggers.criticalChanceBonus = -1
        var battle = try battle(["saintfall_plate", "golden_verdict"], extra: profile)
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(
            .controlMeter(.stun, threshold - 6, threshold), to: battle.enemy,
            sourceID: battle.hero.id, remainingTurns: 0,
        )
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        block(1, owner: .hero, in: &battle)

        // Consolation Prize can grant Wildcard Ray of Frost. Its first hit breaks
        // the caster's Block on Thorns; Saintfall's Holy response steals via Golden Verdict.
        let events = try play(.rayOfFrost, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.rayOfFrost.id }
        #expect(hits.map(\.amount) == [1, 1])
        #expect(battle.gold == 1)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus?.value == preparedDamage)

        let next = try play(.slash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id }?.amount == 3 + preparedDamage)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus == nil)
    }

    private func galeBattle(
        _ ids: [String],
        owner: BattleParticipant = .hero,
        heroDeck: [Ability] = [],
        companionDeck: [Ability] = [],
    ) throws -> BattleState {
        var profile = CombatModifierProfile.zero
        for id in ids {
            let item = try #require(GameContent.unique(matching: id))
            let signature = try #require(item.affixPowers?.first)
            profile.merge(signature.modifiers)
            signature.triggers.apply(to: &profile)
        }
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 200, maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 200, maxMana: 12),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 2000),
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero, appliesFightPacing: false,
        )
        if !heroDeck.isEmpty {
            context.heroDeck = CombatDeck(abilities: heroDeck)
        }
        if !companionDeck.isEmpty {
            context.companionDeck = CombatDeck(abilities: companionDeck)
        }
        return context
    }

    private func galeAttack(id: String = "strike", keyword: Keyword = .physical) -> Ability {
        Ability(id: id, name: id, tier: .basic, directDamage: 2, damageKeyword: keyword, criticalChanceBonus: -1)
    }

    private func galeSupport(id: String) -> Ability {
        Ability(id: id, name: id, tier: .basic, effects: [.shield(.block, 1)])
    }

    @discardableResult
    private func galePlay(_ ability: Ability, owner: BattleParticipant, in context: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
        return try context.recordingEvents { observation in _ = try await BattleCardCombatEngine.resolveDrawnCard(
            card,
            context: &observation,
        ) }
    }

    // 1-5: Play ordinary card, end turn, Dodge during enemy turn, assert return from deck
    // without another copy, complete turn, assert retained in hand/buffer.
    @Test func `gale dodge returns last ordinary play across enemy turn`() throws {
        var context = try galeBattle(
            ["the_returning_gale"],
            heroDeck: [galeAttack(id: "other")],
        )
        // 1. Play an ordinary card (goes to deck bottom, tracked as last ordinary).
        try galePlay(galeAttack(id: "played"), owner: .hero, in: &context)
        try #require(context.roster[.hero].uniques.lastOrdinaryCopyID == context.heroDeck.discarded.last?.copyID)
        // 2. Force the wearer to Dodge during the enemy turn.
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        let heroDeckBefore = context.heroDeck.abilities.map(\.id)
        try #require(!heroDeckBefore.contains("played"))
        try #require(context.heroDeck.discarded.contains { $0.ability.id == "played" })
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        // 3. Same ability returns from deck, no copy remains in deck.
        #expect((context.hand.cards + context.hand.buffer).contains { $0.owner == .hero && $0.ability.id == "played" })
        #expect(!context.heroDeck.abilities.contains { $0.id == "played" })
        // 4. Complete enemy turn, state resets, normal next-turn draws.
        _ = context.endTurn()
        // 5. Returned ability remains available in visible hand or buffer.
        #expect((context.hand.cards + context.hand.buffer).contains { $0.owner == .hero && $0.ability.id == "played" })
    }

    // 6: Full hand + buffered cards preserves FIFO, no loss, later promotion.
    @Test func `gale return respects full hand fifo and promotes later`() throws {
        var context = try galeBattle(
            ["the_returning_gale"],
            heroDeck: [galeAttack(id: "played")],
        )
        try galePlay(galeAttack(id: "played"), owner: .hero, in: &context)
        // Fill visible hand (3) + buffer with existing cards.
        context.hand = BattleHand(cards: [
            BattleCard(id: 101, ability: galeAttack(id: "held1"), owner: .hero),
            BattleCard(id: 102, ability: galeAttack(id: "held2"), owner: .hero),
            BattleCard(id: 103, ability: galeAttack(id: "held3"), owner: .hero),
        ])
        _ = BattleCardCombatEngine.deal(galeAttack(id: "buffered"), owner: .hero, context: &context)
        try #require(context.hand.buffer.map(\.ability.id) == ["buffered"])
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        // Returned card enters buffer FIFO (no overflow loss), visible hand unchanged.
        #expect(context.hand.cards.map(\.ability.id) == ["held1", "held2", "held3"])
        #expect(context.hand.buffer.map(\.ability.id) == ["buffered", "played"])
        // Later promotion when a slot opens preserves order.
        _ = context.hand.remove(id: 101)
        BattleCardCombatEngine.promoteFromBuffer(context: &context)
        #expect(context.hand.cards.map(\.ability.id) == ["held2", "held3", "buffered"])
        #expect(context.hand.buffer.map(\.ability.id) == ["played"])
    }

    // 7: Repeat Dodge before replaying does not duplicate.
    @Test func `gale repeated dodge creates no duplicate`() throws {
        var context = try galeBattle(
            ["the_returning_gale"],
            heroDeck: [galeAttack(id: "other")],
        )
        try galePlay(galeAttack(id: "played"), owner: .hero, in: &context)
        for _ in 0 ..< 2 {
            context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
            _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        }
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.owner == .hero && $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        #expect(copies == 1)
    }

    @Test func `gale ignores no prior play held absent and restrictions`() throws {
        // No prior play -> Dodge does nothing.
        var context = try galeBattle(["the_returning_gale"])
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        #expect(context.hand.totalCount == 0)
        // Already held -> do nothing (no duplicate).
        context = try galeBattle(["the_returning_gale"], heroDeck: [galeAttack(id: "played")])
        try galePlay(galeAttack(id: "played"), owner: .hero, in: &context)
        let trackedCopyID = try #require(context.roster[.hero].uniques.lastOrdinaryCopyID)
        _ = BattleCardCombatEngine.recoverCard(copyID: trackedCopyID, owner: .hero, context: &context)
        let totalBefore = context.hand.totalCount + context.heroDeck.count
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        #expect(context.hand.totalCount + context.heroDeck.count == totalBefore)
        // Absent from deck (already consumed) is covered by repeated dodge above.
        // A stunned owner cannot draw, so Dodge creates no additional copy.
        context = try galeBattle(["the_returning_gale"], heroDeck: [galeAttack(id: "played")])
        try galePlay(galeAttack(id: "played"), owner: .hero, in: &context)
        context.insertEffect(.controlMeter(.stun, 10, 5), to: context.hero, sourceID: context.enemy.id, remainingTurns: 2)
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        #expect(copies == 2)
    }

    @Test func `gale and flight together do not duplicate`() throws {
        var context = try galeBattle(
            ["the_returning_gale", "the_returning_flight"],
            heroDeck: [galeAttack(id: "other")],
        )
        // First Physical card returns immediately via Flight (to hand, not deck).
        try galePlay(galeAttack(id: "played", keyword: .physical), owner: .hero, in: &context)
        #expect((context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        // Dodge later finds already held, does nothing (no duplicate).
        context.insertEffect(.evadeNextHit, to: context.hero, sourceID: context.hero.id, remainingTurns: 0, at: 0)
        _ = context.performTestAction(galeAttack(id: "enemy-hit"), from: .enemy, to: .hero)
        let copies = (context.hand.cards + context.hand.buffer).count(where: { $0.ability.id == "played" })
            + context.heroDeck.abilities.count(where: { $0.id == "played" })
        #expect(copies == 1)
    }

    @Test func `flight returns first physical once and moves without deck cycle`() throws {
        var context = try galeBattle(
            ["the_returning_flight"],
            heroDeck: [galeAttack(id: "other")],
        )
        let deckBefore = context.heroDeck.count
        try galePlay(galeAttack(id: "played", keyword: .physical), owner: .hero, in: &context)
        // Returned to hand (not cycled to deck): deck unchanged (still has "other", no "played" added).
        #expect((context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        #expect(!context.heroDeck.abilities.contains { $0.id == "played" })
        #expect(context.heroDeck.count == deckBefore)
        #expect(context.roster[.hero].uniques.returnedFlightThisTurn == true)
        // Replaying cannot repeatedly return (allowance claimed).
        let returnedCard = try #require((context.hand.cards + context.hand.buffer).first { $0.ability.id == "played" })
        _ = try CombatExecutor.run { try await BattleCardCombatEngine.resolveDrawnCard(returnedCard, context: &context) }
        #expect(!(context.hand.cards + context.hand.buffer).contains { $0.ability.id == "played" })
        // Second play cycled to deck (not returned).
        #expect(context.heroDeck.discarded.contains { $0.ability.id == "played" })
    }

    @Test func `gale tracks non-damaging ordinary but not automatic`() throws {
        var context = try galeBattle(
            ["the_returning_gale"],
            heroDeck: [galeSupport(id: "tracked")],
        )
        // Non-damaging ordinary support qualifies (Sniff Out / Predator's Focus style).
        try galePlay(galeSupport(id: "tracked"), owner: .hero, in: &context)
        #expect(context.roster[.hero].uniques.lastOrdinaryCopyID == context.heroDeck.discarded.first { $0.ability.id == "tracked" }?
            .copyID)
        // Automatic abilities do not replace tracked ordinary card.
        _ = try context.withAutomaticPlay { context in
            let card = BattleCardCombatEngine.deal(galeAttack(id: "auto"), owner: .hero, context: &context)
            return try CombatExecutor.run { try await BattleCardCombatEngine.resolveDrawnCard(card, context: &context) }
        }
        #expect(context.roster[.hero].uniques.lastOrdinaryCopyID == context.heroDeck.discarded.first { $0.ability.id == "tracked" }?
            .copyID)
    }

    @Test func `Patient Edge waits through Knights Answer and a support card for the next manual hit`() throws {
        var context = try battle(["the_patient_edge", "the_knights_answer"], heroBasic: attack())
        block(10, owner: .hero, in: &context)
        let counter = context.recordingResult { observation in enemyHit(5, in: &observation) }
        let hit = try #require(counter.events.first { $0.kind == .abilityDamage && $0.actorID == context.hero.id })
        #expect(!hit.isCritical)
        #expect(context.roster[.hero].uniques.patientEdgeReady == true)
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("The Patient Edge") })
        try play(.block, in: &context)
        #expect(context.roster[.hero].uniques.patientEdgeReady == true)
        let manual = try play(attack(), in: &context)
        #expect(manual.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(context.roster[.hero].uniques.patientEdgeReady == false)
    }

    @Test func `Vipers described readiness waits for manual Health damage`() throws {
        var context = try battle(["vipers_courtesy"])
        CombatExecutor.run { await UniqueCombatEngine.afterUniqueDodge(
            by: context.hero, attackerID: context.enemy.id, in: &context,
        ) }
        BattleTurnEngine.performAction(
            ability: attack(), actor: context.hero, abilityTarget: context.enemy, origin: .counterattack, context: &context,
        )
        #expect(context.roster[.hero].uniques.viperReady == true)
        block(20, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.roster[.hero].uniques.viperReady == true)
        block(0, owner: .enemy, in: &context)
        try play(attack(), in: &context)
        #expect(context.roster[.hero].uniques.viperReady == false)
        #expect(context.roster.hasAffliction(.poison, on: context.enemy))
        #expect(context.roster.hasAffliction(.bleed, on: context.enemy))
    }

    @Test func `restoring a combatant runtime restores its prepared attacks without changing its snapshot`() throws {
        var context = try battle(["the_patient_edge"])
        block(10, owner: .hero, in: &context)
        _ = enemyHit(5, in: &context)
        context.roster.mutateRuntime(for: context.hero) {
            $0.talents.history.preparations.insert(.doublePoison)
        }
        let prepared = context.roster.hero

        let firstPhysical = try play(attack(), in: &context)
        let firstPoison = try play(attack(.poison), in: &context)
        #expect(firstPhysical.contains { $0.kind == .abilityDamage && $0.isCritical })
        let firstPoisonDamage = try #require(firstPoison.first {
            $0.kind == .abilityDamage && $0.keyword == .poison
        }?.amount)
        #expect(!context.effectSummaries(of: context.hero).contains { $0.text.contains("Unstable Culture") })
        #expect(context.roster.hero != prepared)

        context.roster.update(prepared)
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("The Patient Edge") })
        #expect(context.effectSummaries(of: context.hero).contains { $0.text.contains("Unstable Culture") })
        let restoredPhysical = try play(attack(), in: &context)
        let restoredPoison = try play(attack(.poison), in: &context)
        #expect(restoredPhysical.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(restoredPoison.first { $0.kind == .abilityDamage && $0.keyword == .poison }?.amount == firstPoisonDamage)
        #expect(prepared.uniques.patientEdgeReady)
        #expect(prepared.talents.history.preparations.contains(.doublePoison))
    }
}
