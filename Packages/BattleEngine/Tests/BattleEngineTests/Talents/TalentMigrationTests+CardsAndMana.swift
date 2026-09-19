import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `closedCircuit spends mana deals stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(closedCircuit: true)))
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterSpendMana(
                ManaPayment(
                    payer: ctx.roster.hero.combatant,
                    balanceBefore: ctx.mana(of: ctx.roster.hero.combatant) + 3,
                    balanceAfter: ctx.mana(of: ctx.roster.hero.combatant),
                ),
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `eyeOfTheStorm stun restores mana`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(eyeOfTheStorm: true)))
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentMana = 0 }
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.stun,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.mana(of: battle.hero) > 0)
    }

    @Test func `furnaceRhythm primes physical repeat`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(mana: ManaTriggers(furnaceRhythm: true)),
            heroAbilities: [
                .slash,
                Ability(id: "burn-test", name: "Burn Test", tier: .basic, directDamage: 2, damageKeyword: Keyword.burn),
            ],
        )
        let burnAbility = Ability(id: "x", name: "X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn)
        _ = battle.withEngineContext { ctx in
            cardReactions(
                burnAbility,
                in: &ctx,
            )
        }
        #expect(battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
        let physical = Ability(id: "phys", name: "Phys", tier: .basic, directDamage: 5, damageKeyword: Keyword.physical)
        let healthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            cardReactions(
                physical,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) < healthBefore)
        #expect(!battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
    }

    @Test func `phantom counter plays a drawn card without consuming ordinary card rewards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            attack: AttackTriggers(thirdCardReturnsToHand: true),
            dodge: DodgeTriggers(phantomCounter: true),
        ))
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.uniques.owners[.hero, default: .init()].cardsPlayed = 2
        let healthBefore = battle.roster.enemy.currentHealth
        let events = CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        )
        #expect(battle.roster.enemy.currentHealth < healthBefore)
        #expect(battle.hand.isEmpty)
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.slash.id])
        #expect(battle.uniques.owners[.hero]?.cardsPlayed == 2)
        #expect(!events.contains { $0.abilityName == "The Returning Gale" })
        #expect(battle.resolution.depth(.draw) == 0)
    }

    @Test func `snapping jaws resolves fangs bleed and leech`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(dodge: DodgeTriggers(onDodgeCounterBasicAttack: true)),
            heroAbilities: [.fangs],
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        let events = CombatTriggerEngine.afterDodge(
            by: battle.hero, attackerID: battle.enemy.id, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth > 5)
        #expect(battle.roster.hasAffliction(.bleed, on: battle.enemy))
        #expect(events.contains { $0.abilityName == Ability.fangs.name && $0.keyword == .bleed })
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.fangs.id])
    }

    @Test func `dazing swipe only delays after damaging cards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            enemyTurn: EnemyTurnTriggers(attackDelayEnemyTurnChancePercent: 1),
        ))
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
            heroTriggers: CombatTraitTriggers(mana: ManaTriggers(furnaceRhythm: true)),
            heroAbilities: [.slash],
        )
        _ = battle.withEngineContext { ctx in
            cardReactions(
                Ability(id: "burn-x", name: "Burn X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn),
                in: &ctx,
            )
        }
        #expect(battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
        _ = battle.endTurn()
        #expect(!battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
    }

    @Test func `pyromancer restores mana on burn empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(onEmpowerBurnRestoreMana: 1)))
        var ability = Ability.meteor
        _ = battle.withEngineContext { ctx in
            _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &ability, actor: ctx.roster.hero.combatant, context: &ctx,
            )
        }
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.currentMana == 3)
    }

    @Test func `frost guard adds freeze damage to empowerment`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(empowerFreezeDamageBonus: 1)))
        var ability = Ability.frostbolt
        _ = battle.withEngineContext { ctx in
            _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &ability, actor: ctx.roster.hero.combatant, context: &ctx,
            )
        }
        #expect(ability.damageComponents.first(where: { $0.keyword == .freeze })?.amount == 5)
    }

    @Test func `dark recovery deals stun when spending last mana`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(spendLastManaStunDamage: 3)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentMana = 0 }
        }
        let before = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            _ = CombatTriggerEngine.afterSpendMana(
                ManaPayment(
                    payer: ctx.roster.hero.combatant,
                    balanceBefore: ctx.mana(of: ctx.roster.hero.combatant) + 1,
                    balanceAfter: ctx.mana(of: ctx.roster.hero.combatant),
                ),
                in: &ctx,
            )
        }
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
