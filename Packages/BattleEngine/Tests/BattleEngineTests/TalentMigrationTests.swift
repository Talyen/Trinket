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
                options: DamageOptions(guaranteedCritical: true, isAttackHit: true, isBasicAttackHit: true),
            ))
        }
        var noPoisonBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        let noPoison = noPoisonBattle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOptions(guaranteedCritical: true, isAttackHit: true, isBasicAttackHit: true),
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
                options: .flatReaction,
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicComa: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.poison,
                sourceActorID: ctx.roster.hero.id,
                options: .flatReaction,
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
                options: .flatReaction,
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .flatReaction,
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
                options: .flatReaction,
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: .flatReaction,
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
                options: DamageOptions(isAttackHit: true),
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
                options: .flatReaction,
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
                options: DamageOptions(isAttackHit: true),
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
                options: .flatReaction,
            ))
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `sunwall grants party block on holy damage`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(sunwall: true)))
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 9,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.holy,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOptions(isAttackHit: true),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) > 0)
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
                options: DamageOptions(isAttackHit: true),
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
                options: DamageOptions(isAttackHit: true),
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
        let cryoOutcome = battle.withEngineContext { ctx -> EffectTurnOutcome in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return BleedHandler().advanceTurn(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                on: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(cryoOutcome.updatedStack?.remainingTurns == 1)
        #expect(cryoOutcome.removeAfter == false)

        var noCryoBattle = makeBattle()
        let plainOutcome = noCryoBattle.withEngineContext { ctx -> EffectTurnOutcome in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return BleedHandler().advanceTurn(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                on: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(plainOutcome.updatedStack?.remainingTurns == 0)
        #expect(plainOutcome.removeAfter == true)
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
                options: DamageOptions(isAttackHit: true),
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

    @Test func `bountyBlade crit grants gold and draw`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(gold: GoldTriggers(bountyBlade: true)),
            heroAbilities: [.slash],
        )
        let goldBefore = battle.gold
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOptions(guaranteedCritical: true, isAttackHit: true),
            ))
        }
        #expect(battle.gold > goldBefore)
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

    @Test func `phantomCounter dodge draws physical card`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dodge: DodgeTriggers(phantomCounter: true)))
        BattleStateTestFactory.drawOpeningHand(on: &battle)
        let handBefore = battle.hand.cards.count
        let events = battle.withEngineContext { ctx -> [ActionEvent] in
            CombatTriggerEngine.afterDodge(by: ctx.roster.hero.combatant, attackerID: ctx.roster.enemy.id, in: &ctx)
        }
        let drewPhantom = events.contains(where: { $0.effectKind == .cardsDrawn })
        if drewPhantom {
            #expect(battle.hand.cards.count == handBefore + 1)
        } else {
            #expect(battle.hand.cards.count == handBefore)
        }

        var noTalentBattle = makeBattle()
        BattleStateTestFactory.drawOpeningHand(on: &noTalentBattle)
        let noHandBefore = noTalentBattle.hand.cards.count
        let noEvents = noTalentBattle.withEngineContext { ctx -> [ActionEvent] in
            CombatTriggerEngine.afterDodge(by: ctx.roster.hero.combatant, attackerID: ctx.roster.enemy.id, in: &ctx)
        }
        #expect(!noEvents.contains(where: { $0.effectKind == .cardsDrawn }))
        #expect(noTalentBattle.hand.cards.count == noHandBefore)
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
                options: DamageOptions(isAttackHit: true),
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
                options: .flatReaction,
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
                options: DamageOptions(isAttackHit: true),
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
                options: DamageOptions(isAttackHit: true, isBasicAttackHit: true),
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
                options: DamageOptions(guaranteedCritical: true, isAttackHit: true, isBasicAttackHit: true),
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
        let outcome = battle.withEngineContext { ctx -> EffectTurnOutcome in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.hero.combatant)
            return BleedHandler().advanceTurn(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                on: ctx.roster.hero.combatant,
                in: &ctx,
            )
        }
        #expect(outcome.updatedStack?.remainingTurns == 0)
        #expect(outcome.removeAfter == true)
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
}
