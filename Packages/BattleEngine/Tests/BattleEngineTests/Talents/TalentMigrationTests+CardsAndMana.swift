import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test(arguments: [Keyword.physical, .freeze])
    func `each party member owns its prepared elemental repeat`(keyword: Keyword) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.furnaceRhythm = keyword == .physical
        profile.triggers.temperCycle = keyword == .freeze
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1000, heroModifiers: profile, companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        let burn = Ability(id: "burn", name: "Burn", tier: .basic, directDamage: 1, damageKeyword: .burn)
        let followup = Ability(id: "followup", name: "Followup", tier: .basic, directDamage: 2, damageKeyword: keyword)

        let prime = BattleCardCombatEngine.deal(burn, owner: .hero, context: &battle)
        _ = try battle.playCard(cardID: prime.id)
        let partner = BattleCardCombatEngine.deal(followup, owner: .companion, context: &battle)
        let partnerEvents = try battle.playCard(cardID: partner.id).events
        #expect(partnerEvents.count { $0.kind == .abilityDamage && $0.abilityID == followup.id } == 1)
        #expect(battle.roster.hero.talents.turn.primedRepeatKeywords.contains(keyword))

        let own = BattleCardCombatEngine.deal(followup, owner: .hero, context: &battle)
        let ownEvents = try battle.playCard(cardID: own.id).events
        #expect(ownEvents.count { $0.kind == .abilityDamage && $0.abilityID == followup.id } == 2)
        #expect(!battle.roster.hero.talents.turn.primedRepeatKeywords.contains(keyword))
    }

    @Test func `closedCircuit spends mana deals stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.closedCircuit = true })
        let enemyHealthBefore = battle.health(of: battle.enemy)
        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: battle.roster.hero.combatant,
                balanceBefore: battle.mana(of: battle.roster.hero.combatant) + 3,
                balanceAfter: battle.mana(of: battle.roster.hero.combatant),
            ),
            in: &battle,
        ) }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `eyeOfTheStorm stun restores mana`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.eyeOfTheStorm = true })
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentMana = 0 }
        _ = battle.resolveTestDamage(6, keyword: .stun)
        #expect(battle.mana(of: battle.hero) > 0)
    }

    @Test func `phantom counter plays a drawn card without consuming ordinary card rewards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers {
            $0.thirdCardReturnsToHand = true
            $0.phantomCounter = true
        })
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.roster[.hero].uniques.turn.cardsPlayed = 2
        let healthBefore = battle.roster.enemy.currentHealth
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }
        #expect(battle.roster.enemy.currentHealth < healthBefore)
        #expect(battle.hand.isEmpty)
        #expect(battle.heroDeck.discarded.map(\.ability.id) == [Ability.slash.id])
        #expect(battle.roster[.hero].uniques.turn.cardsPlayed == 2)
        #expect(!events.contains { $0.abilityName == "The Returning Gale" })
        #expect(battle.resolution.depth(.draw) == 0)
    }

    @Test func `snapping jaws resolves fangs bleed and leech`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers { $0.onDodgeCounterBasicAttack = true },
            heroAbilities: [.fangs],
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }
        #expect(battle.roster.hero.currentHealth > 5)
        #expect(battle.roster.hasAffliction(.bleed, on: battle.enemy))
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.fangs.id])
    }

    @Test func `dazing swipe only delays after damaging cards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.attackDelayEnemyTurnChancePercent = 1 })
        for ability in [Ability.block, .slash] {
            _ = cardReactions(
                ability,
                in: &battle,
            )
            #expect(battle.roster.enemy.talents.battle.actionDelays
                == (ability.id == Ability.slash.id ? 1 : 0))
        }
    }

    @Test func `primed repeat expires at turn end`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers { $0.furnaceRhythm = true },
            heroAbilities: [.slash],
        )
        _ = cardReactions(
            Ability(id: "burn-x", name: "Burn X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn),
            in: &battle,
        )
        #expect(battle.roster.hero.talents.turn.primedRepeatKeywords.contains(Keyword.physical))
        _ = battle.endTurn()
        #expect(!battle.roster.hero.talents.turn.primedRepeatKeywords.contains(Keyword.physical))
    }

    @Test func `pyromancer restores mana on burn empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.onEmpowerBurnRestoreMana = 1 })
        var ability = Ability.meteor
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.roster.hero.combatant, context: &battle,
        ) }
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.currentMana == 3)
    }

    @Test func `frost guard adds freeze damage to empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.empowerFreezeDamageBonus = 1 })
        var ability = Ability.frostbolt
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.roster.hero.combatant, context: &battle,
        ) }
        #expect(ability.damageComponents.first(where: { $0.keyword == .freeze })?.amount == 6)
    }

    @Test func `dark recovery deals stun when spending last mana`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.spendLastManaStunDamage = 3 })
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentMana = 0 }
        let before = battle.health(of: battle.enemy)
        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: battle.roster.hero.combatant,
                balanceBefore: battle.mana(of: battle.roster.hero.combatant) + 1,
                balanceAfter: battle.mana(of: battle.roster.hero.combatant),
            ),
            in: &battle,
        ) }
        #expect(before - battle.health(of: battle.enemy) == 3)
    }

    @Test(arguments: [Keyword.physical, .freeze])
    func `mixed burn card prepares the next matching card instead of repeating itself`(keyword: Keyword) {
        var triggers = CombatTraitTriggers()
        triggers.furnaceRhythm = keyword == .physical
        triggers.temperCycle = keyword == .freeze
        var battle = makeBattle(heroTriggers: triggers)
        let card = Ability(id: "mixed", name: "Mixed", tier: .basic, damageComponents: [
            DamageComponent(1, keyword: .burn), DamageComponent(1, keyword: keyword),
        ])
        let before = battle.health(of: battle.enemy)
        _ = cardReactions(card, in: &battle)
        #expect(battle.health(of: battle.enemy) == before)
        #expect(battle.roster.hero.talents.turn.primedRepeatKeywords.contains(keyword))
        _ = cardReactions(card, in: &battle)
        #expect(battle.health(of: battle.enemy) < before)
        #expect(battle.roster.hero.talents.turn.primedRepeatKeywords.contains(keyword))
    }

    @Test func `Ray of Frost gives each damaging hit a Rimewind draw chance`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["frost_whelp_freeze_t1_1"])
        profile.triggers.freezeAttackDrawChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.rayOfFrost], enemyMaxHealth: 100,
            companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.companionDeck = CombatDeck(abilities: [.iceShot, .stargaze])
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .rayOfFrost, owner: .companion)
        battle.hand.append(card)

        let events = try battle.playCard(cardID: card.id).events

        #expect(events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Rimewind" } == 2)
        #expect(battle.hand.cards.count == 2)
    }
}
