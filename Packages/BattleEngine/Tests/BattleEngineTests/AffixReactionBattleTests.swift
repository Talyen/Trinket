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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(onBleedApplyPoison: 1))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        let poison = battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
    }

    @Test func contagionCanIncreasePoisonInsteadOfDecreasing() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .poison(8), remainingTurns: 0, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(poisonDecayIncreaseChance: 1.0))
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        let poison = battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 9)
    }

    @Test func frostburnIncreasesFreezeDamageAgainstBurningEnemies() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "frost", name: "Frost", tier: .basic, directDamage: 1, damageKeyword: .freeze),
            ]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(freezeDamageWhileBurningBonus: 2))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 3)
    }

    @Test func cascadingGrantsBlockWhenBlockBreaks() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 2, damageKeyword: .physical),
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            companion: passiveCompanion(maxHealth: 1),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 6),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(blockBrokenBlockFlat: 4))
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

    @Test func symbiosisSharesHeroLeechWithCompanionButNotNormalHeals() throws {
        let leechStrike = Ability(
            id: "leech-strike",
            name: "Leech Strike",
            tier: .basic,
            directDamage: 10,
            damageKeyword: .physical,
            hasLeech: true
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [leechStrike, healAbility(amount: 10)], maxHealth: 30),
            companion: passiveCompanion(maxHealth: 20),
            enemy: passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(companionLeechSharePercent: 1.0))
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 10 }
            context.roster.mutateRuntime(for: context.roster.companion.combatant) { $0.currentHealth = 5 }
        }

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        let companionAfterLeech = battle.health(of: battle.companion)
        try #expect(companionAfterLeech > 5)

        // Fill the companion so a subsequent Heal targets the damaged hero only.
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.currentHealth = $0.maxHealth
            }
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 10 }
        }
        let companionAtFull = battle.health(of: battle.companion)
        if try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) == nil {
            _ = BattleTestFixtures.endTurn(on: &battle)
            _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        }
        try #expect(battle.health(of: battle.companion) == companionAtFull)
        try #expect(battle.health(of: battle.hero) > 10)
    }

    @Test func secondWindHealsOnlyOnceWhenHealthFallsLow() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                // Non-lethal: drop below 25% without killing so Death's Door does not own the hit.
                Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 16, damageKeyword: .physical),
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], maxHealth: 20),
            companion: passiveCompanion(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(onceBelowHealthPercentThreshold: 0.25, onceBelowHealthPercentHeal: 3))
        )

        let first = BattleTestFixtures.endTurn(on: &battle)
        let second = BattleTestFixtures.endTurn(on: &battle)

        try #expect(first.contains { $0.abilityName == "Second Wind" && $0.amount == 3 })
        try #expect(!second.contains { $0.abilityName == "Second Wind" })
        // Second chip is lethal after the heal; Death's Door owns that hit and leaves 1 HP.
        try #expect(second.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(battle.health(of: battle.hero) == 1)
    }

    @Test func shatterAddsDamageWhileEnemyIsFrozen() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1, damageKeyword: .physical),
            ]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 1), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(damageWhileTargetFrozenBonus: 2))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 3)
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
                ),
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

        let dotLost = DoTDamage.resolveTurnDamage(
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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(spendManaBlockFlat: 2))
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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(holyDamageBlockFlat: 1, holyDamageCleanseCount: 1, holyDamageHealFlat: 3, holyDamagePurgeCount: 1))
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 2, sourceActorID: enemy.id)],
            for: hero
        )
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(dodgeGoldFlat: 2, dodgeBlockFlat: 3))
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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(stunDealPhysicalFlat: 3, enemyStunnedApplyMarked: true))
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
        // Toughness 100 DR% = 100 / 180 = 55.56%.
        // Baseline damage: 50 * (1 - 5/9) = 22.22 → 22 health lost.
        try #expect(baseline == 22)

        var shreddingContext = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 200,
            targetPrimaryStats: PrimaryStats(toughness: 100),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(ignoreEnemyMitigationPercent: 0.5))
        )
        let shreddingHero = shreddingContext.roster.hero.combatant
        let shreddingEnemy = shreddingContext.roster.enemy.combatant
        let withShredding = shreddingContext.resolveDamage(
            DamageRequest(amount: 50, target: shreddingEnemy, keyword: .physical, sourceActorID: shreddingHero.id, options: options)
        ).healthLost
        // 50% mitigation shred reduces DR% to 27.78%.
        // Shredded damage: 50 * (1 - 5/18) = 36.11 → 36 health lost.
        try #expect(withShredding == 36)
    }

    @Test func dazedAddsDamageWhileEnemyIsStunned() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1, damageKeyword: .physical),
            ]),
            companion: passiveCompanion(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(damageWhileTargetStunnedBonus: 1))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}
