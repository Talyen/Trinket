import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct AffixReactionBattleTests {
    private func hero(
        abilities: [Ability],
        maxHealth: Int = 20
    ) -> Combatant {
        Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: maxHealth,
            abilities: abilities
        )
    }

    private func passiveCompanion(maxHealth: Int = 20) -> Combatant {
        BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion, maxHealth: maxHealth)
    }

    private func passiveEnemy(maxHealth: Int = 100) -> Combatant {
        BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: maxHealth)
    }

    private func bleedAbility(potency: Int) -> Ability {
        Ability(
            id: "bleed-\(potency)",
            name: "Bleed",
            tier: .basic,
            directDamage: 0,
            description: "Bleed",
            effects: [.bleed(potency)]
        )
    }

    private func healAbility(amount: Int) -> Ability {
        Ability(
            id: "heal-\(amount)",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Heal",
            effects: [.instantHeal(.health, amount)]
        )
    }

    @Test func infectedAppliesPoisonWhenBleedIsApplied() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [bleedAbility(potency: 1)]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            heroModifiers: CombatModifierProfile(onBleedApplyPoison: 1)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        let poison = battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
    }

    @Test func relentlessRefreshesBleedInsteadOfAddingAStack() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [bleedAbility(potency: 2)]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            heroModifiers: CombatModifierProfile(refreshBleedOnReapply: true)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        if try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) == nil {
            _ = BattleTestFixtures.endTurn(on: &battle)
            _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        }

        let bleeds = battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }
        try #expect(bleeds.count == 1)
        try #expect(bleeds.first?.remainingTicks == Effect.bleedDoTTickCount)
    }

    @Test func frostburnDealsFreezeDamageEveryThirdBurnTick() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(8), remainingTicks: 0, sourceActorID: "hero")
            ],
            heroModifiers: CombatModifierProfile(
                everyNthBurnTickCount: 3,
                everyNthBurnTickFreezeDamage: 1
            )
        )

        var events: [ActionEvent] = []
        for _ in 0 ..< 3 {
            events.append(contentsOf: BattleTestFixtures.endTurn(on: &battle))
        }

        try #expect(events.contains { $0.kind == .status && $0.keyword == .freeze && $0.amount == 1 })
    }

    @Test func cascadingGrantsBlockWhenBlockBreaks() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 2, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            companion: passiveCompanion(maxHealth: 1),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTicks: 6)
            ],
            heroModifiers: CombatModifierProfile(blockBrokenBlockFlat: 4)
        )

        // Strike's 2 damage breaks the 1-point Block, Cascading regrants 4, then
        // end-of-round decay halves it to 2.
        _ = BattleTestFixtures.endTurn(on: &battle)

        let block = battle.activeEffects(of: battle.hero).first { active in
            if case let .shield(keyword, points) = active.effect {
                return keyword == .block && points == 2
            }
            return false
        }
        try #expect(block != nil)
    }

    @Test func symbiosisSharesHeroHealingWithCompanion() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 5, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [healAbility(amount: 10)]),
            companion: passiveCompanion(maxHealth: 20),
            enemy: enemy,
            activeCompanionEffects: [
                ActiveEffect(id: 1, effect: .bleed(4), remainingTicks: 1, sourceActorID: "enemy")
            ],
            heroModifiers: CombatModifierProfile(companionHealSharePercent: 0.50)
        )

        // Enemy strike + bleed tick damage the companion during endTurn.
        _ = BattleTestFixtures.endTurn(on: &battle)
        let damagedCompanionHealth = battle.health(of: battle.companion)
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.companion) > damagedCompanionHealth)
    }

    @Test func secondWindHealsOnlyOnceWhenHealthFallsLow() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                // Non-lethal: drop below 25% without killing so Death's Door does not own the hit.
                Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 16, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], maxHealth: 20),
            companion: passiveCompanion(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                onceBelowHealthPercentThreshold: 0.25,
                onceBelowHealthPercentHeal: 3
            )
        )

        let first = BattleTestFixtures.endTurn(on: &battle)
        let second = BattleTestFixtures.endTurn(on: &battle)

        try #expect(first.contains { $0.abilityName == "Second Wind" && $0.amount == 3 })
        try #expect(!second.contains { $0.abilityName == "Second Wind" })
        // Second chip is lethal after the heal; Death's Door owns that hit and leaves 1 HP.
        try #expect(second.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(battle.health(of: battle.hero) == 1)
    }

    @Test func shatterAddsFreezeDamageWhileEnemyIsFrozen() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "frost", name: "Frost", tier: .basic, directDamage: 1, damageKeyword: .freeze)
            ]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 1), remainingTicks: 0)
            ],
            heroModifiers: CombatModifierProfile(freezeDamageWhileFrozenBonus: 1)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }

    @Test func damageAfterDodgeSurvivesDoTTickAndAppliesOnDirectHit() throws {
        let heroCombatant = hero(
            abilities: [
                Ability(
                    id: "strike",
                    name: "Strike",
                    tier: .basic,
                    directDamage: 1,
                    damageKeyword: .physical
                )
            ],
            maxHealth: 50
        )
        let enemyCombatant = passiveEnemy(maxHealth: 100)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: heroCombatant),
                companion: CombatantRuntime(combatant: passiveCompanion()),
                enemy: CombatantRuntime(combatant: enemyCombatant)
            ),
            rng: SeededRandomNumberGenerator(seed: 2),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        context.roster.mutateRuntime(for: heroCombatant) { $0.pendingDamageAfterDodge = 3 }

        let dotLost = DoTDamage.resolveTick(
            basePotency: 1,
            keyword: .burn,
            target: enemyCombatant,
            sourceActorID: heroCombatant.id,
            in: &context
        ).healthLost
        try #expect(dotLost == 1)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 3)

        let directLost = context.resolveDamage(
            DamageRequest(
                amount: 1,
                target: enemyCombatant,
                keyword: .physical,
                sourceActorID: heroCombatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: true,
                    applyDodge: false,
                    qualifiesForAmbush: true
                )
            )
        ).healthLost
        try #expect(directLost == 4)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 0)
    }

    @Test func aetherwardGrantsBlockWhenSpendingMana() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(spendManaBlockFlat: 2)
        )
        let hero = context.roster.hero.combatant

        let events = CombatReactionEngine.afterSpendMana(by: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Aetherward" && $0.amount == 2 })
        let block = context.roster.activeEffects(for: hero).contains { active in
            if case let .shield(keyword, points) = active.effect {
                return keyword == .block && points == 2
            }
            return false
        }
        try #expect(block)
    }

    @Test func holyDamageAffixesGrantBlockCleanseHealAndPurge() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                holyDamageBlockFlat: 1,
                holyDamageCleanseCount: 1,
                holyDamageHealFlat: 3,
                holyDamagePurgeCount: 1
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 2, sourceActorID: enemy.id)],
            for: hero
        )
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTicks: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatReactionEngine.afterHolyDamageDealt(to: enemy, source: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Sanctum" })
        try #expect(events.contains { $0.abilityName == "Absolving" })
        try #expect(events.contains { $0.abilityName == "Beacon" })
        try #expect(events.contains { $0.abilityName == "Nullifying" })
        try #expect(!context.roster.activeEffects(for: hero).map(\.effect).contains(where: \.isRemovableDebuff))
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
        try #expect(context.roster.health(for: hero) == 4)
    }

    @Test func paydayAndUntouchableFireWhenDodging() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(dodgeGoldFlat: 2, dodgeBlockFlat: 3)
        )
        let hero = context.roster.hero.combatant

        let events = CombatReactionEngine.afterDodge(by: hero, in: &context)

        try #expect(context.gold == 2)
        try #expect(events.contains { $0.abilityName == "Payday" && $0.amount == 2 })
        try #expect(events.contains { $0.abilityName == "Untouchable" && $0.amount == 3 })
    }

    @Test func knockoutAndBrandingFireWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            heroModifiers: CombatModifierProfile(stunDealPhysicalFlat: 3, enemyStunnedApplyMarked: true)
        )
        let enemy = context.roster.enemy.combatant

        let events = CombatReactionEngine.afterEnemyStunned(in: &context)

        try #expect(context.roster.health(for: enemy) == 17)
        try #expect(events.contains { $0.effectKind == .markedApplied })
        let marked = context.roster.activeEffects(for: enemy).contains {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
        try #expect(marked)
    }

    @Test func shreddingIgnoresPortionOfEnemyMitigation() throws {
        let options = DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var baselineContext = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 200,
            targetPrimaryStats: PrimaryStats(toughness: 100)
        )
        let baselineHero = baselineContext.roster.hero.combatant
        let baselineEnemy = baselineContext.roster.enemy.combatant
        let baseline = baselineContext.resolveDamage(
            DamageRequest(amount: 50, target: baselineEnemy, keyword: .physical, sourceActorID: baselineHero.id, options: options)
        ).healthLost
        try #expect(baseline == 30)

        var shreddingContext = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 200,
            targetPrimaryStats: PrimaryStats(toughness: 100),
            heroModifiers: CombatModifierProfile(ignoreEnemyMitigationPercent: 0.5)
        )
        let shreddingHero = shreddingContext.roster.hero.combatant
        let shreddingEnemy = shreddingContext.roster.enemy.combatant
        let withShredding = shreddingContext.resolveDamage(
            DamageRequest(amount: 50, target: shreddingEnemy, keyword: .physical, sourceActorID: shreddingHero.id, options: options)
        ).healthLost
        try #expect(withShredding == 40)
    }

    @Test func dazedAddsDamageWhileEnemyIsStunned() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1, damageKeyword: .physical)
            ]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTicks: 0)
            ],
            heroModifiers: CombatModifierProfile(damageWhileTargetStunnedBonus: 1)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}
