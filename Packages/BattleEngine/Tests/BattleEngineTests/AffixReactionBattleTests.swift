// swiftlint:disable file_length
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

private func affixBleedAbility(potency: Int) -> Ability {
    Ability(
        id: "bleed-\(potency)",
        name: "Bleed",
        tier: .basic,
        directDamage: 0,
        description: "Bleed",
        effects: [.bleed(potency)]
    )
}

private func affixHealAbility(amount: Int) -> Ability {
    Ability(
        id: "heal-\(amount)",
        name: "Heal",
        tier: .basic,
        directDamage: 0,
        description: "Heal",
        effects: [.instantHeal(.health, amount)]
    )
}

// swiftlint:disable:next type_body_length
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

    @Test func infectedAppliesPoisonWhenBleedIsApplied() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [affixBleedAbility(potency: 1)]),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    onBleedApplyPoison: 1
                )
            ))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        let poison = battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
    }

    @Test func contagionCanIncreasePoisonInsteadOfDecreasing() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .poison(8), remainingTurns: 0, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDecayIncreaseChance: 1.0
                )
            ))
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
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    freezeDamageWhileBurningBonus: 2
                )
            ))
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
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 1),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 6),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockBrokenBlockFlat: 4
                )
            ))
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
            hero: hero(abilities: [leechStrike, affixHealAbility(amount: 10)], maxHealth: 30),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    companionLeechSharePercent: 1.0
                )
            ))
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

    @Test func symbiosisSharePercentIsCappedAtFullLeech() throws {
        func companionHealth(afterSharing restored: Int, percent: Double) -> Int {
            let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 40)
            var context = BattleTestFixtures.makeContext(
                hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 30),
                companion: companion,
                enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30),
                heroModifiers: CombatModifierProfile(
                    triggers: CombatTraitTriggers(
                        healing: HealingTriggers(
                            companionLeechSharePercent: percent
                        )
                    )
                )
            )
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 5 }
            _ = CombatTriggerEngine.shareHeroLeechWithCompanion(restored: restored, in: &context)
            return context.roster.health(for: companion)
        }

        try #expect(companionHealth(afterSharing: 10, percent: 1.5) == companionHealth(afterSharing: 10, percent: 1.0))
        try #expect(companionHealth(afterSharing: 10, percent: 1.5) > companionHealth(afterSharing: 10, percent: 0.5))
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
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentThreshold: 0.25
                ),
                healing: HealingTriggers(
                    onceBelowHealthPercentHeal: 3
                )
            ))
        )

        let first = BattleTestFixtures.endTurn(on: &battle)
        let second = BattleTestFixtures.endTurn(on: &battle)

        try #expect(first.contains {
            $0.abilityName == "Second Wind" && $0.amount == battle.paced(3, sourceActorID: battle.hero.id)
        })
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
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 1), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetFrozenBonus: 2
                )
            ))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 3)
    }

    @Test func aetherwardGrantsBlockWhenSpendingMana() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaBlockFlat: 2
                )
            ))
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterSpendMana(by: hero, amountSpent: 3, in: &context)

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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    holyDamageBlockFlat: 1
                ),
                healing: HealingTriggers(
                    holyDamageHealFlat: 3
                ),
                cleanse: CleanseTriggers(
                    holyDamageCleanseCount: 1,
                    holyDamagePurgeCount: 1
                )
            ))
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

        let events = CombatTriggerEngine.afterHolyDamageDealt(to: enemy, source: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Sanctum" })
        try #expect(events.contains { $0.abilityName == "Absolving" })
        try #expect(events.contains { $0.abilityName == "Beacon" })
        try #expect(events.contains { $0.abilityName == "Nullifying" })
        try #expect(!context.roster.activeEffects(for: hero).map(\.effect).contains(where: \.isRemovableDebuff))
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
        try #expect(context.roster.health(for: hero) == 1 + context.paced(3, sourceActorID: hero.id))
    }

    @Test func paydayAndUntouchableFireWhenDodging() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(
                    dodgeBlockFlat: 3,
                    dodgeGoldFlat: 2
                )
            ))
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: context.roster.enemy.id, in: &context)

        try #expect(context.gold == 2)
        try #expect(events.contains { $0.abilityName == "Payday" && $0.amount == 2 })
        try #expect(events.contains { $0.abilityName == "Untouchable" && $0.amount == 3 })
    }

    @Test func knockoutAndBrandingFireWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunnedApplyMarked: true,
                    stunDealPhysicalFlat: 3
                )
            ))
        )
        let enemy = context.roster.enemy.combatant

        let events = CombatTriggerEngine.afterEnemyStunned(in: &context)

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

    @Test func companionStunAffixesFireWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            companionModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    enemyStunnedApplyMarked: true,
                    stunDealPhysicalFlat: 3
                )
            ))
        )
        let enemy = context.roster.enemy.combatant
        let companion = context.roster.companion.combatant

        let events = CombatTriggerEngine.afterEnemyStunned(in: &context)

        try #expect(context.roster.health(for: enemy) == 17)
        try #expect(events.contains { $0.effectKind == .markedApplied && $0.actorName == companion.name })
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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    ignoreEnemyMitigationPercent: 0.5
                )
            ))
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
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetStunnedBonus: 1
                )
            ))
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}

extension AffixReactionBattleTests {
    @Test func whiplashDodgeDoesNotRetriggerOnDodge() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            targetEffects: [ActiveEffect(id: 1, effect: .evadeNextHit, remainingTurns: 1)],
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(dodgeDealStunFlat: 3)
                )
            ),
            enemyModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(dodgeDealStunFlat: 9)
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        let heroHealth = context.roster.health(for: hero)
        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: enemy.id, in: &context)

        try #expect(context.roster.health(for: enemy) == 20)
        try #expect(context.roster.health(for: hero) == heroHealth)
        try #expect(!events.contains { $0.abilityName == "Whiplash" && $0.amount == 9 })
    }
}

struct AffixUnderrepresentedReactionTests {
    @Test func disruptingPurgesWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(
                        enemyStunnedPurgeCount: 1
                    )
                )
            )
        )
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatTriggerEngine.afterEnemyStunned(in: &context)

        try #expect(events.contains { $0.abilityName == "Disrupting" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func unmakingPurgesOnCriticalHit() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    attack: AttackTriggers(
                        criticalPurgeCount: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatTriggerEngine.afterCriticalHit(to: enemy, source: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Unmaking" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func arcaneWardGrantsBlockWhenGainingMana() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mana: ManaTriggers(
                        gainManaBlockFlat: 2
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterGainMana(by: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Arcane Ward" && $0.amount == 2 })
    }

    @Test func siphoningAndBloodPriceFireOnLeech() throws {
        let source = Combatant(
            id: "source",
            name: "Source",
            role: .hero,
            maxHealth: 50,
            maxMana: 5,
            abilities: []
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: source, initialMana: 0),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: target)
            ),
            rng: SeededRandomNumberGenerator(seed: BattleTestFixtures.deterministicNonCriticalSeed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mana: ManaTriggers(
                        leechRestoreManaFlat: 2
                    ),
                    gold: GoldTriggers(
                        leechGoldFlat: 1
                    )
                )
            ),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterLeech(by: hero, target: context.roster.enemy.combatant, in: &context)

        try #expect(events.contains { $0.abilityName == "Siphoning" && $0.amount == 2 })
        try #expect(events.contains { $0.abilityName == "Blood Price" && $0.amount == 1 })
        try #expect(context.gold == 1)
        try #expect(context.roster.runtime(for: hero)?.currentMana == 2)
    }

    @Test func bountyGrantsGoldWhenEnemyIsDefeated() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 4
                    )
                )
            )
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 4)
        try #expect(events.contains { $0.abilityName == "Bounty" && $0.amount == 4 })
    }

    @Test func bountyGrantsGoldFromCompanionWhenAlive() throws {
        var context = BattleTestFixtures.makePipelineContext()
        let companion = context.roster.companion.combatant
        context = BattleState(
            roster: context.roster,
            rng: context.rng,
            nextEffectID: context.nextEffectID,
            nextEventID: context.nextEventID,
            events: context.events,
            gold: context.gold,
            initialGold: context.initialGold,
            heroModifiers: .zero,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 3
                    )
                )
            ),
            enemyModifiers: .zero
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 3)
        try #expect(events.contains {
            $0.abilityName == "Bounty" && $0.amount == 3 && $0.actorName == companion.name
        })
    }

    @Test func bountyGrantsCompanionGoldWhenHeroIsDead() throws {
        var context = BattleTestFixtures.makePipelineContext()
        let hero = context.roster.hero.combatant
        let companion = context.roster.companion.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        context = BattleState(
            roster: context.roster,
            rng: context.rng,
            nextEffectID: context.nextEffectID,
            nextEventID: context.nextEventID,
            events: context.events,
            gold: context.gold,
            initialGold: context.initialGold,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 4
                    )
                )
            ),
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 3
                    )
                )
            ),
            enemyModifiers: .zero
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 3)
        try #expect(events.count == 1)
        try #expect(events.contains {
            $0.abilityName == "Bounty" && $0.amount == 3 && $0.actorName == companion.name
        })
    }

    @Test func gildedIncreasesGoldGrantedByPercent() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(goldGainedPercent: 0.10)
        )
        let hero = context.roster.hero.combatant

        try #expect(context.goldGranted(for: 10, sourceActorID: hero.id) == 11)
        context.addGold(10, sourceActorID: hero.id)
        try #expect(context.gold == 11)
    }

    @Test func sidestepAndWhiplashFireWhenDodging() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(
                        dodgeDealStunFlat: 3
                    ),
                    dodge: DodgeTriggers(
                        dodgeHealFlat: 3
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }

        let expectedHeal = context.paced(3, sourceActorID: hero.id)
        let expectedStun = context.paced(3, sourceActorID: hero.id)
        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: context.roster.enemy.id, in: &context)

        try #expect(context.roster.health(for: hero) == 5 + expectedHeal)
        try #expect(events.contains { $0.abilityName == "Sidestep" && $0.amount == expectedHeal })
        try #expect(context.roster.health(for: enemy) == 20 - expectedStun)
        try #expect(events.contains { $0.abilityName == "Whiplash" && $0.keyword == .stun })
        try #expect(context.roster.activeEffects(for: enemy).contains { active in
            if case let .controlMeter(keyword, amount, _) = active.effect {
                return keyword == .stun && amount > 0
            }
            return false
        })
    }

    @Test func blurAddsDodgeChanceWhileBelowHealthThreshold() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dodge: DodgeTriggers(
                        dodgeChanceBelowHealthPercentThreshold: 0.50,
                        dodgeChanceBelowHealthPercentBonus: 0.15
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 4 }
        var state = DamageResolutionState(
            amount: 1,
            combatant: hero,
            sourceActorID: "enemy",
            damageKeyword: .physical,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: true
        )

        let chance = DamagePipeline.dodgeChance(for: state, in: context)
        try #expect(abs(chance - 0.15) < 0.0001)

        context.roster.mutateRuntime(for: hero) { $0.currentHealth = $0.maxHealth }
        state = DamageResolutionState(
            amount: 1,
            combatant: hero,
            sourceActorID: "enemy",
            damageKeyword: .physical,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: true
        )
        try #expect(DamagePipeline.dodgeChance(for: state, in: context) == 0)
    }

    @Test func windfallHealsWhenPaydayGrantsGold() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dodge: DodgeTriggers(
                        dodgeGoldFlat: 2
                    ),
                    gold: GoldTriggers(
                        gainGoldBonusHealSelf: 3
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }

        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: context.roster.enemy.id, in: &context)

        try #expect(context.gold == 2)
        try #expect(context.roster.health(for: hero) == 5 + context.paced(3, sourceActorID: hero.id))
        try #expect(events.contains { $0.abilityName == "Payday" && $0.amount == 2 })
        try #expect(events.contains {
            $0.effectKind == .instantHeal && $0.amount == context.paced(3, sourceActorID: hero.id)
        })
    }

    @Test func cauterizeDealsBurnDamageWithoutApplyingBurn() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        onBurnApplyPoison: 1,
                        onBleedDealBurnDamage: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        let healthBefore = context.roster.health(for: enemy)

        let events = CombatTriggerEngine.afterBleedApplied(
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )

        try #expect(context.roster.health(for: enemy) == healthBefore - 1)
        try #expect(events.contains { $0.keyword == Keyword.burn && $0.amount == 1 })
        try #expect(!context.roster.activeEffects(for: enemy).contains { $0.keyword == Keyword.burn })
        try #expect(!context.roster.activeEffects(for: enemy).contains { $0.keyword == Keyword.poison })
    }
}

extension AffixUnderrepresentedReactionTests {
    @Test func ashenWakeAppliesPoisonWhenBurnIsApplied() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        onBurnApplyPoison: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        let events = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .burn,
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )

        let poison = context.roster.activeEffects(for: enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
        try #expect(events.contains { $0.keyword == .poison })

        let poisonEvents = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .poison,
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )
        try #expect(poisonEvents.isEmpty)
        try #expect(context.roster.activeEffects(for: enemy).count(where: { $0.keyword == .poison }) == 1)
        try #expect(
            context.roster.activeEffects(for: enemy).first { $0.keyword == .poison }?.effect.potency == 1
        )
    }
}
