import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeCardChainRegressionTests {
    @Test(arguments: [false, true])
    func `nested critical attacks retain their actor without requiring battle history`(tracksEvents: Bool) throws {
        var battle = BattleState(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            tracksLog: false, tracksEvents: tracksEvents, dealOpeningHand: false,
            appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.block])
        battle.companionDeck = CombatDeck(abilities: [.stab])
        battle.appendEffect(.nextStrikeCritical, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let ability = Ability(id: "nested-draw", name: "Nested Draw", tier: .skill, effects: [.drawAndPlayCards(2)])
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let result = try CombatExecutor.run {
            try await BattleCardCombatEngine.resolveDrawnCard(card, context: &battle)
        }

        // A partner's nested Critical Hit must not extend the Hero's chain.
        #expect(result.criticalAttackActorIDs == [battle.companion.id])
        #expect(battle.health(of: battle.enemy) < 100)
        #expect(battle.events.isEmpty == !tracksEvents)
    }

    @Test func `dance of blades repeats after the drawn attack Critically Hits`() throws {
        let item = try #require(GameContent.unique(matching: "dance_of_blades"))
        let power = try #require(item.resolvedPower(at: 0))
        var profile = CombatModifierProfile.zero
        power.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.stab, .block])

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.stab.id && $0.isCritical })
        #expect(battle.heroDeck.abilities.isEmpty)
    }

    @Test func `a defeated dance of blades owner cannot grant Tailwind afterward`() {
        var profile = CombatantTalentCatalog.profile(for: ["frost_whelp_dodge_t1_2"])
        profile.triggers.onDodgeDrawAndPlayCardChainOnCrit = true
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1,
            companionModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.stab])
        battle.heroDeck = CombatDeck(abilities: [.block])
        battle.appendEffect(.thorns(4), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.companion, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.health(of: battle.enemy) < 100)
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.block.id])
        #expect(!events.contains { $0.abilityName == "Tailwind" })
    }

    @Test func `dance of blades does not repeat for critical Leech on a noncritical attack`() throws {
        let item = try #require(GameContent.unique(matching: "dance_of_blades"))
        let power = try #require(item.resolvedPower(at: 0))
        var profile = CombatModifierProfile.zero
        power.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            heroModifiers: profile,
            rngSeed: 17,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.fangs, .block])

        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(events.contains { $0.keyword == .leech && $0.isCritical })
        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.fangs.id && !$0.isCritical })
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.block.id])
        #expect(battle.turnCadence.cardsPlayed[.hero] == 1)
    }
}
