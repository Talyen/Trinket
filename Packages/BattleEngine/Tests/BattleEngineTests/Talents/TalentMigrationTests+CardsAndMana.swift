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
            enemyMaxHealth: 1000, heroModifiers: profile, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let burn = Ability(id: "burn", name: "Burn", tier: .basic, directDamage: 1, damageKeyword: .burn)
        let followup = Ability(id: "followup", name: "Followup", tier: .basic, directDamage: 2, damageKeyword: keyword)

        let prime = BattleCardCombatEngine.deal(burn, owner: .hero, context: &battle)
        _ = try battle.playCard(cardID: prime.id)
        let partner = BattleCardCombatEngine.deal(followup, owner: .companion, context: &battle)
        let partnerEvents = try battle.playCard(cardID: partner.id).events
        #expect(partnerEvents.count { $0.kind == .abilityDamage && $0.abilityID == followup.id } == 1)
        #expect(battle.primedRepeatKeywords.contains(keyword))

        let own = BattleCardCombatEngine.deal(followup, owner: .hero, context: &battle)
        let ownEvents = try battle.playCard(cardID: own.id).events
        #expect(ownEvents.count { $0.kind == .abilityDamage && $0.abilityID == followup.id } == 2)
        #expect(!battle.primedRepeatKeywords.contains(keyword))
    }

    @Test func `closedCircuit spends mana deals stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.closedCircuit = true })
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(
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
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.eyeOfTheStorm = true })
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentMana = 0 }
        _ = battle.resolveTestDamage(6, keyword: .stun)
        #expect(battle.mana(of: battle.hero) > 0)
    }

    @Test func `furnaceRhythm primes physical repeat`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers.configured { $0.furnaceRhythm = true },
            heroAbilities: [
                .slash,
                Ability(id: "burn-test", name: "Burn Test", tier: .basic, directDamage: 2, damageKeyword: Keyword.burn),
            ],
        )
        let burnAbility = Ability(id: "x", name: "X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn)
        _ = cardReactions(
            burnAbility,
            in: &battle,
        )
        #expect(battle.primedRepeatKeywords.contains(Keyword.physical))
        let physical = Ability(id: "phys", name: "Phys", tier: .basic, directDamage: 5, damageKeyword: Keyword.physical)
        let healthBefore = battle.health(of: battle.enemy)
        _ = cardReactions(
            physical,
            in: &battle,
        )
        #expect(battle.health(of: battle.enemy) < healthBefore)
        #expect(!battle.primedRepeatKeywords.contains(Keyword.physical))
    }

    @Test func `phantom counter plays a drawn card without consuming ordinary card rewards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured {
            $0.thirdCardReturnsToHand = true
            $0.phantomCounter = true
        })
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.uniques.owners[.hero, default: .init()].cardsPlayed = 2
        let healthBefore = battle.roster.enemy.currentHealth
        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }
        #expect(battle.roster.enemy.currentHealth < healthBefore)
        #expect(battle.hand.isEmpty)
        #expect(battle.heroDeck.discarded.map(\.ability.id) == [Ability.slash.id])
        #expect(battle.uniques.owners[.hero]?.cardsPlayed == 2)
        #expect(!events.contains { $0.abilityName == "The Returning Gale" })
        #expect(battle.resolution.depth(.draw) == 0)
    }

    @Test func `snapping jaws resolves fangs bleed and leech`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers.configured { $0.onDodgeCounterBasicAttack = true },
            heroAbilities: [.fangs],
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }
        #expect(battle.roster.hero.currentHealth > 5)
        #expect(battle.roster.hasAffliction(.bleed, on: battle.enemy))
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.fangs.id])
    }

    @Test func `dazing swipe only delays after damaging cards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.attackDelayEnemyTurnChancePercent = 1 })
        for ability in [Ability.block, .slash] {
            _ = cardReactions(
                ability,
                in: &battle,
            )
            #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id, default: 0]
                == (ability.id == Ability.slash.id ? 1 : 0))
        }
    }

    @Test func `primed repeat expires at turn end`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers.configured { $0.furnaceRhythm = true },
            heroAbilities: [.slash],
        )
        _ = cardReactions(
            Ability(id: "burn-x", name: "Burn X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn),
            in: &battle,
        )
        #expect(battle.primedRepeatKeywords.contains(Keyword.physical))
        _ = battle.endTurn()
        #expect(!battle.primedRepeatKeywords.contains(Keyword.physical))
    }

    @Test func `pyromancer restores mana on burn empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.onEmpowerBurnRestoreMana = 1 })
        var ability = Ability.meteor
        _ = CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.roster.hero.combatant, context: &battle,
        ) }
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.currentMana == 3)
    }

    @Test func `frost guard adds freeze damage to empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.empowerFreezeDamageBonus = 1 })
        var ability = Ability.frostbolt
        _ = CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.roster.hero.combatant, context: &battle,
        ) }
        #expect(ability.damageComponents.first(where: { $0.keyword == .freeze })?.amount == 6)
    }

    @Test func `dark recovery deals stun when spending last mana`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.spendLastManaStunDamage = 3 })
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentMana = 0 }
        let before = battle.health(of: battle.enemy)
        _ = CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(
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
        #expect(battle.primedRepeatKeywords.contains(keyword))
        _ = cardReactions(card, in: &battle)
        #expect(battle.health(of: battle.enemy) < before)
        #expect(battle.primedRepeatKeywords.contains(keyword))
    }
}
