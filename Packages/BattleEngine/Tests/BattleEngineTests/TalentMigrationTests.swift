import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

// swiftlint:disable file_length - migration suite exceeds 550
// swiftlint:disable:next type_body_length - migration suite intentionally comprehensive
struct TalentMigrationTests {
    private func makeBattle(
        heroTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        companionTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        heroAbilities: [Ability] = [.slash],
        initialGold: Int = 0,
        seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: [.bash],
            enemyMaxHealth: 100,
            heroMaxMana: 12,
            heroMana: 5,
            companionMaxMana: 12,
            initialGold: initialGold,
            heroModifiers: CombatModifierProfile(triggers: heroTriggers),
            companionModifiers: CombatModifierProfile(triggers: companionTriggers),
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false,
        )
    }

    @Test func `warChest guarantees physical critical at 50 gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(damage: DamageTriggers(warChest: true)),
            initialGold: 50,
        )
        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }
        #expect(outcome.isCritical)
    }

    @Test func `pressurePoint doubles physical crit vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let crit = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        var noPoisonBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        let noPoison = noPoisonBattle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        #expect(crit.healthLost > noPoison.healthLost)
    }

    @Test func `toxicComa doubles poison vs stunned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicComa: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(Keyword.stun, 100, 10), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let withStun = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.poison,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicComa: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.poison,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        #expect(withStun.healthLost > without.healthLost)
    }

    @Test func `septicemia doubles bleed vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let withPoison = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        #expect(withPoison.healthLost > without.healthLost)
    }

    @Test func `elementalParadox doubles freeze vs burning`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let withBurn = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        #expect(withBurn.healthLost > without.healthLost)
    }

    @Test func `batteringRam consumes block for bonus damage`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(batteringRam: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost > 10)
        #expect(!battle.activeEffects(of: battle.hero).contains {
            if case .shield = $0.effect {
                true
            } else {
                false
            }
        })
    }

    @Test func `storedImpact stores blocked and empowers next physical`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(storedImpact: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        let heroID = battle.hero.id
        let stored = battle.withEngineContext { $0.storedBlockedDamageByActorID[heroID] ?? 0 }
        #expect(stored > 0)
        let second = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(second.healthLost > 10)
    }

    @Test func `seismicReversal returns blocked as stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(seismicReversal: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 8), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `sunwall grants companion block on holy damage`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(sunwall: true)))
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 9,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.holy,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) > 0)
    }

    @Test func `mirrored half damage physical to poison`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicTransfusion: true)))
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.keyword == Keyword.poison })
    }

    @Test func `shatterpoint freeze detonates bleed`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(shatterpoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .bleed(6), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 5,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(!battle.activeEffects(of: battle.enemy).contains {
            if case .bleed = $0.effect {
                true
            } else {
                false
            }
        })
    }

    @Test func `cryostasis preserves bleed on frozen`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(cryostasis: true)))
        let cryoOutcome = battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.enemy.combatant,
                battle: &ctx,
            )
        }
        #expect(cryoOutcome.currentEffect?.remainingTurns == 1)
        #expect(cryoOutcome.currentEffect != nil)

        var noCryoBattle = makeBattle()
        let plainOutcome = noCryoBattle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.enemy.combatant,
                battle: &ctx,
            )
        }
        #expect((plainOutcome.currentEffect?.remainingTurns ?? 0) == 0)
        #expect(plainOutcome.currentEffect == nil)
    }

    @Test func `closedCircuit spends mana deals stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mana: ManaTriggers(closedCircuit: true)))
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterSpendMana(by: ctx.roster.hero.combatant, amountSpent: 3, in: &ctx)
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
            CombatTriggerEngine.afterCardPlayed(
                ability: burnAbility,
                by: ctx.roster.hero.combatant,
                abilityTarget: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
        let physical = Ability(id: "phys", name: "Phys", tier: .basic, directDamage: 5, damageKeyword: Keyword.physical)
        let healthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCardPlayed(
                ability: physical,
                by: ctx.roster.hero.combatant,
                abilityTarget: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) < healthBefore)
        #expect(!battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
    }

    @Test func `purifyingWaters cleanse heals per effect`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)))
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1), ActiveEffect(id: 2, effect: .burn(1), remainingTurns: 1)],
                for: ctx.roster.hero.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.hero.combatant,
                target: ctx.roster.hero.combatant,
                removedCount: 2,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) > 10)
    }

    @Test func `cleanSlate overheal cleanses`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.hero.combatant)
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "test-heal")
        }
        #expect(!battle.activeEffects(of: battle.hero).contains {
            if case .poison = $0.effect {
                true
            } else {
                false
            }
        })
    }

    @Test func `crownfall purge deals holy per effect`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            let outcome = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "purge",
                source: ctx.roster.hero.combatant,
                target: ctx.roster.enemy.combatant,
                in: &ctx,
            )
            _ = outcome
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
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
            _ = CombatTriggerEngine.afterCardPlayed(
                ability: ability, by: battle.hero, abilityTarget: battle.enemy, in: &battle,
            )
            #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id, default: 0]
                == (ability.id == Ability.slash.id ? 1 : 0))
        }
    }

    @Test func `batteringRam and storedImpact stack on same hit`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            damage: DamageTriggers(batteringRam: true),
            block: BlockTriggers(storedImpact: true),
        ))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 6), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
            ctx.storedBlockedDamageByActorID[ctx.roster.hero.id] = 4
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost == 20)
    }

    @Test func `purifyingWaters triggers via living party not just source`() {
        var battle = makeBattle(
            companionTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)),
        )
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.hero.combatant)
        }
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.hero.combatant,
                target: ctx.roster.hero.combatant,
                removedCount: 1,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) > 10)
    }

    @Test func `crownfall triggers via living party`() {
        var battle = makeBattle(
            companionTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)),
        )
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            _ = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "purge",
                source: ctx.roster.hero.combatant,
                target: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `storedImpact cross-owner companion block empowers hero`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(storedImpact: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.companion.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        let companionID = battle.companion.id
        let storedCompanion = battle.withEngineContext { $0.storedBlockedDamageByActorID[companionID] ?? 0 }
        #expect(storedCompanion > 0)
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost > 10)
        #expect(battle.withEngineContext { $0.storedBlockedDamageByActorID.isEmpty })
    }

    @Test func `primed repeat expires at turn end`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(mana: ManaTriggers(furnaceRhythm: true)),
            heroAbilities: [.slash],
        )
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCardPlayed(
                ability: Ability(id: "burn-x", name: "Burn X", tier: .basic, directDamage: 1, damageKeyword: Keyword.burn),
                by: ctx.roster.hero.combatant,
                abilityTarget: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
        _ = battle.endTurn()
        #expect(!battle.withEngineContext { $0.primedRepeatKeywords.contains(Keyword.physical) })
    }

    @Test func `warChest does not crit below 50 gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(damage: DamageTriggers(warChest: true)),
            initialGold: 49,
        )
        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }
        #expect(!outcome.isCritical)
    }

    @Test func `pressurePoint needs critical`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let nonCrit = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        var critBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        critBattle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let crit = critBattle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        #expect(crit.healthLost > nonCrit.healthLost)
    }

    @Test func `cleanSlate caps at one per turn`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 2),
                ActiveEffect(id: 2, effect: .burn(1), remainingTurns: 2),
            ], for: ctx.roster.hero.combatant)
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "first")
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "second")
        }
        let remainingDebuffs = battle.activeEffects(of: battle.hero).count(
            where: { $0.effect.keyword == .poison || $0.effect.keyword == .burn },
        )
        #expect(remainingDebuffs == 1)
    }
}

extension TalentMigrationTests {
    @Test func `cryostasis does not preserve bleed on frozen ally`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(cryostasis: true)))
        let outcome = battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.hero.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.hero.combatant,
                battle: &ctx,
            )
        }
        #expect((outcome.currentEffect?.remainingTurns ?? 0) == 0)
        #expect(outcome.currentEffect == nil)
    }

    @Test func `crownfall does not damage when enemy purges ally buff`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        let heroHealthBefore = battle.health(of: battle.hero)
        _ = battle.withEngineContext { ctx in
            _ = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "enemy-purge",
                source: ctx.roster.enemy.combatant,
                target: ctx.roster.hero.combatant,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) == heroHealthBefore)
    }

    @Test func `purifyingWaters does not heal when enemy cleanses`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)))
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.enemy.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.enemy.combatant)
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.enemy.combatant,
                target: ctx.roster.enemy.combatant,
                removedCount: 1,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) == enemyHealthBefore)
    }

    @Test func `cleanSlate does not cleanse when enemy overheals`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
            ctx.roster.mutateRuntime(for: ctx.roster.enemy.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                source: ctx.roster.enemy.combatant,
                abilityName: "test-heal",
            )
        }
        let buffRemains = battle.activeEffects(of: battle.enemy).contains {
            if case .shield = $0.effect {
                true
            } else {
                false
            }
        }
        #expect(buffRemains)
    }

    @Test func `stalwart oath grants 6 block on stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(onStunEnemyGainBlock: 6)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 20,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.stun,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 6)
    }

    @Test func `gilded carapace grants 2 block on stun`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(onStunEnemyGainBlock: 2)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 20,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.stun,
                sourceActorID: ctx.roster.companion.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test func `skullcracker adds stun only against stunned enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(attack: AttackTriggers(physicalVsStunnedStunBuildup: 2)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 1,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .controlMeter })
        _ = battle.withEngineContext { ctx in
            _ = ControlMeterEngine.applyMeterCharge(
                20, keyword: .stun, to: ctx.roster.enemy.combatant,
                sourceActorID: ctx.roster.hero.id, applyFightPacing: false, in: &ctx,
            )
            ctx.resolveDamage(DamageRequest(
                amount: 1,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
    }

    @Test func `slip away dodges the first attack each combat`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeFirstAttackEachCombat: true)))
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.activeEffects(for: battle.companion).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        })
    }

    @Test func `bloodprice heals on attacks against bleeding enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(onAttackBleedingEnemyHeal: 2)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
                for: ctx.roster.enemy.combatant,
            )
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) {
                $0.currentHealth = $0.maxHealth - 5
            }
        }
        let missing = battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 2,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero) == missing - 2)
    }

    @Test func `golden guard grants block while carrying enough gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(block: BlockTriggers(blockWhileGoldThreshold: 10, blockWhileGoldAmount: 2)),
            initialGold: 10,
        )
        let events = CombatTriggerEngine.turnBlock(for: battle.hero, in: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 2)
        #expect(events.contains(where: { $0.abilityName == "Golden Guard" }))

        var poor = makeBattle(
            heroTriggers: CombatTraitTriggers(block: BlockTriggers(blockWhileGoldThreshold: 10, blockWhileGoldAmount: 2)),
        )
        _ = CombatTriggerEngine.turnBlock(for: poor.hero, in: &poor)
        #expect(BattleTestFixtures.shieldPoints(for: poor.hero, in: poor) == 0)
    }

    @Test func `pulverize applies bleed and stun once per turn`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(attack: AttackTriggers(firstPhysicalBleedStunPerTurn: true)))
        battle.appliesFightPacing = false
        for _ in 0 ..< 2 {
            _ = battle.withEngineContext { ctx in
                ctx.resolveDamage(DamageRequest(
                    amount: 1,
                    target: ctx.roster.enemy.combatant,
                    keyword: Keyword.physical,
                    sourceActorID: ctx.roster.hero.id,
                    options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
                ))
            }
        }
        let bleeds = battle.activeEffects(of: battle.enemy).filter(\.effect.isBleed)
        #expect(bleeds.count == 1)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .controlMeter(.stun, 1, 20) })
    }

    @Test func `flashover doubles burn ticks against frozen enemies`() {
        for frozen in [false, true] {
            var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(burnDoubleVsFrozenChancePercent: 1.0)))
            battle.appliesFightPacing = false
            _ = battle.withEngineContext { ctx in
                if frozen {
                    _ = ControlMeterEngine.applyMeterCharge(
                        20, keyword: .freeze, to: ctx.roster.enemy.combatant,
                        sourceActorID: ctx.roster.hero.id, applyFightPacing: false, in: &ctx,
                    )
                }
            }
            let before = battle.health(of: battle.enemy)
            let active = ActiveEffect(id: battle.nextEffectID, effect: .burn(4), remainingTurns: 0, sourceActorID: battle.hero.id)
            _ = EffectHandlersTestSupport.dispatchTick(active, target: battle.enemy, battle: &battle)
            #expect(before - battle.health(of: battle.enemy) == (frozen ? 4 : 2))
        }
    }

    @Test func `aether shield grants block on first overheal each turn`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealFirstBlockPerTurn: 3)))
        for expected in [3, 3] {
            _ = battle.withEngineContext { ctx in
                _ = HealingEngine.resolveHeal(
                    HealRequest(amount: 5, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                    in: &ctx,
                )
            }
            #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == expected)
        }
        battle.turnCount += 1
        _ = battle.withEngineContext { ctx in
            _ = HealingEngine.resolveHeal(
                HealRequest(amount: 5, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                in: &ctx,
            )
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 6)
    }

    @Test func `reclaimed reagents converts overheal to block up to four`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealShieldCap: 4)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            _ = HealingEngine.resolveHeal(
                HealRequest(amount: 10, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                in: &ctx,
            )
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 4)
    }

    @Test func `rimewind deals freeze damage on dodge`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(control: ControlTriggers(dodgeDealFreezeFlat: 2)))
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant, attackerID: battle.roster.enemy.id, in: &battle,
        )
        #expect(before - battle.health(of: battle.enemy) == 2)
    }

    @Test func `vanish guarantees critical after dodge`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(dodge: DodgeTriggers(onDodgeNextAttackGuaranteedCritical: true)))
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant, attackerID: battle.roster.enemy.id, in: &battle,
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingGuaranteedCriticalAfterDodge == true)
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
            _ = CombatTriggerEngine.afterSpendMana(by: ctx.roster.hero.combatant, amountSpent: 1, in: &ctx)
        }
        #expect(before - battle.health(of: battle.enemy) == 3)
    }

    @Test func `golden opportunity draws on large gold gains`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(gold: GoldTriggers(gainGoldDrawThreshold: 5)))
        battle.heroDeck.putOnBottom(.slash)
        let events = battle.withEngineContext { ctx in
            ctx.grantGoldEvent(5, to: ctx.roster.hero.combatant, abilityName: "test")
        }
        #expect(events.contains(where: { $0.effectKind == .cardsDrawn }))
    }

    @Test func `searing bind extends stun against burning enemies`() {
        for burning in [false, true] {
            var battle = makeBattle(heroTriggers: CombatTraitTriggers(control: ControlTriggers(stunExtendVsBurning: true)))
            battle.appliesFightPacing = false
            _ = battle.withEngineContext { ctx in
                if burning {
                    ctx.roster.setActiveEffects(
                        [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                        for: ctx.roster.enemy.combatant,
                    )
                }
                _ = ControlMeterEngine.applyMeterCharge(
                    20, keyword: .stun, to: ctx.roster.enemy.combatant,
                    sourceActorID: ctx.roster.hero.id, applyFightPacing: false, in: &ctx,
                )
            }
            #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
            #expect(battle.additionalControlSkipsByCombatantID[battle.roster.enemy.id, default: 0] == (burning ? 1 : 0))
        }
    }

    @Test func `intense heat only boosts phoenix damage against burning enemies`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(damage: DamageTriggers(companionDamageVsBurningMultiplier: 1.25)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let before = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.burn,
                sourceActorID: ctx.roster.companion.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(before - battle.health(of: battle.enemy) == 5)
    }

    @Test func `scorched earth weakens burning attackers`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mitigation: MitigationTriggers(burningEnemyDamageReductionFlat: 1)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 5,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost == 4)
    }

    @Test func `pickpocket steals extra gold from poisoned enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            attack: AttackTriggers(onAttackStealGold: 1),
            gold: GoldTriggers(stealGoldBonusVsPoisoned: 1),
        ))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 2,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.gold == 2)
    }

    @Test func `bone crushing bites harder through block`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(physicalDamageVsBlockedBonus: 2)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost == 1)
    }

    @Test func `plated hide grants block when hit`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(onHit: OnHitTriggers(onHitGainBlock: 2)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 3,
                target: ctx.roster.companion.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test func `spiked shell grows thorns from retained block`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(retainedBlockGainThornsPercent: 0.5)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 8), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
            _ = DefensePoolEngine.decayBlock(on: ctx.roster.companion.combatant, in: &ctx)
        }
        let thorns = battle.activeEffects(of: battle.companion).reduce(0) { sum, active in
            guard case let .thorns(stacks) = active.effect else { return sum }
            return sum + stacks
        }
        #expect(thorns == 2)
    }

    @Test func `enduring shell retains half block`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(blockRetainsHalf: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 50), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
            _ = DefensePoolEngine.decayBlock(on: ctx.roster.companion.combatant, in: &ctx)
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 25)
    }

    @Test func `seismic roar stuns while below half health`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            attack: AttackTriggers(attackStunBuildupBelowHealthThreshold: 0.5, attackStunBuildupBelowHealthBonus: 2),
        ))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) {
                $0.currentHealth = $0.maxHealth / 2 - 1
            }
            _ = ControlMeterEngine.applyMeterCharge(
                18, keyword: .stun, to: ctx.roster.enemy.combatant,
                sourceActorID: ctx.roster.hero.id, applyFightPacing: false, in: &ctx,
            )
            ctx.resolveDamage(DamageRequest(
                amount: 1,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
    }
}
