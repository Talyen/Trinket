import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleBoundaryRegressionTests {
    @Test(arguments: [false, true])
    func `combined empowerment discounts remain a free payment at integer limits`(prepared: Bool) throws {
        var profile = CombatModifierProfile.zero
        if prepared {
            profile.triggers.firstEmpowermentCostReduction = Int.max
        } else {
            profile.triggers.empowermentCostReduction = Int.max
            profile.triggers.empowerBurnCostReduction = Int.max
        }
        var battle = makeBattle(profile: profile)
        if prepared {
            battle.roster.mutateRuntime(for: battle.hero) { $0.talents.pending.nextManaEmpowerDiscount = Int.max }
        }
        let ability = Ability(id: "burn", name: "Burn", tier: .basic, directDamage: 1, damageKeyword: .burn)
        var budget = ManaEmpowermentBudget(ability: ability, actor: battle.hero, in: battle)
        let payment = try #require(budget.nextPayment())
        #expect(payment.ownMana == 0)
        #expect(payment.partnerMana == 0)
        #expect(payment.block == 0)
    }

    @Test(arguments: [false, true])
    func `Bleed duration bonuses saturate for ordinary and critical applications`(critical: Bool) throws {
        var profile = CombatModifierProfile(bleedDurationBonus: Int.max)
        profile.triggers.bleedDurationFromCriticalBonus = critical ? 1 : 0
        profile.triggers.bleedDurationVsPoisonedBonus = 1
        var battle = makeBattle(profile: profile)
        battle.appendEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        _ = CombatExecutor.run { await BattleTurnEngine.applyDoTStackFromDamage(
            keyword: .bleed, potency: 1, to: battle.enemy,
            sourceActorID: battle.hero.id, isCritical: critical, context: &battle,
        ) }
        let bleed = try #require(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed })
        #expect(bleed.remainingTurns == Int.max)
    }

    @Test func `party damage auras combine without overflowing`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.partyDamageBonusWhileCompanionFullHealth = Int.max
        profile.triggers.partyHolyDamageBonusWhileCompanionFullHealth = 1
        let battle = makeBattle(profile: profile)
        let state = DamageResolutionState(
            amount: 1, combatant: battle.enemy, sourceActorID: battle.hero.id,
            damageKeyword: .holy, options: .attack(),
        )
        let bonus = CombatTriggerEngine.partyAuraDamageBonus(
            for: state, source: battle.roster.hero, damageKeyword: .holy,
            targetIsPoisoned: false, targetIsBurning: false, in: battle,
        )
        #expect(bonus == Int.max)
    }

    @Test func `maximum Mana gain reports actual restoration at capacity`() throws {
        var battle = makeBattle(profile: CombatModifierProfile(maximumManaBonus: Int.max))
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = Int.max }
        let outcome = EffectHandlersTestSupport.dispatch(.maximumManaBonus(1), battle: &battle)
        let gain = try #require(outcome.events.first { $0.effectKind == .resourceGain })
        #expect(gain.amount == 0)
        #expect(battle.mana(of: battle.hero) == Int.max)
    }

    @Test(arguments: [false, true])
    func `turn start victories stop later recovery and opening rewards`(opening: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        if opening {
            profile.triggers.startBattleBonusMana = 1
            profile.triggers.onGainManaHealFlat = 2
            profile.triggers.startBattleBlock = 1
            profile.triggers.startBattleThorns = 1
            profile.triggers.startBattleBonusGold = 1
        } else {
            profile.triggers.goldEveryNTurnsInterval = 1
            profile.triggers.goldEveryNTurnsAmount = 1
            profile.triggers.gainGoldBonusHealSelf = 2
        }
        profile.triggers.onHealDealHoly = 1
        profile.triggers.healthRegenFirstTurnsDuration = opening ? 0 : 3
        profile.triggers.healthRegenFirstTurnsAmount = 4
        profile.triggers.healthRegenAboveHalfHealth = opening ? 0 : 4
        var battle = makeBattle(profile: profile)
        battle.turnCount = opening ? 0 : 1
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 11 }
        battle.roster.mutateRuntime(for: battle.enemy) { $0.currentHealth = 1 }
        _ = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: battle.hero) == 13)
        #expect(battle.gold == (opening ? 0 : 1))
        #expect(battle.activeEffects(of: battle.hero).isEmpty)
    }

    @Test(arguments: [false, true])
    func `zero actual Gold grants do not trigger restoration`(atCapacity: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.gainGoldBonusHealSelf = 2
        profile.triggers.criticalChanceBonus = -1
        var battle = makeBattle(profile: profile)
        battle.roster.hero.currentHealth = 10
        if atCapacity {
            _ = battle.recordGoldGain(Int.max)
        }

        let gain = CombatExecutor.run { await battle.grantGold(
            atCapacity ? 1 : 0, to: battle.hero, abilityName: "Gold",
        ) }

        #expect(gain.applied == 0)
        #expect(battle.health(of: battle.hero) == 10)
        #expect(!gain.events.contains { $0.effectKind == .instantHeal })
        if !atCapacity {
            _ = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
            #expect(battle.health(of: battle.hero) == 12)
        }
    }

    @Test func `party Mana summaries saturate without reducing either recipient's gain`() throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: Int.max),
            companion: CombatantFixtures.passiveCompanion(maxMana: Int.max),
            enemy: CombatantFixtures.passiveEnemy(), heroMana: 0, companionMana: 0,
        )
        battle.appliesFightPacing = false
        let ability = Ability(
            id: "party-mana", name: "Party Mana", tier: .skill,
            operations: [.effect(TargetedEffect(.resourceGain(.mana, Int.max), target: .eachAlly))],
        )

        let events = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )

        #expect(battle.mana(of: battle.hero) == Int.max)
        #expect(battle.mana(of: battle.companion) == Int.max)
        #expect(events.filter { $0.effectKind == .resourceGain }.map(\.amount) == [Int.max, Int.max])
        let summary = try #require(events.last { $0.kind == .ability })
        #expect(summary.appliedEffectSummaries == ["restore \(Int.max) Mana"])
    }

    @Test func `Holy damage preparations preserve saturated bonuses`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.holyDamageNextHitBonus = 1
        profile.triggers.holyDamageNextAttackHolyBonus = 1
        var battle = makeBattle(profile: profile)
        battle.roster.hero.talents.pending.nextHitBonus = Int.max
        battle.roster.hero.talents.pending.nextAttackHolyBonus = Int.max

        _ = CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(
            to: battle.enemy, source: battle.hero, in: &battle,
        ) }

        #expect(battle.roster.hero.talents.pending.nextHitBonus == Int.max)
        #expect(battle.roster.hero.talents.pending.nextAttackHolyBonus == Int.max)
    }

    @Test func `large Focused bonuses safely publish their percentage and details`() throws {
        var battle = makeBattle(profile: .zero)
        let outcome = EffectHandlersTestSupport.dispatch(.criticalChanceBonus(1e20, 2), battle: &battle)
        let event = try #require(outcome.events.first { $0.effectKind == .criticalChanceApplied })
        #expect(event.amount == Int.max)
        #expect(Effect.criticalChanceBonus(1e20, 2).summary.contains("+\(Int.max)%"))
        #expect(Effect.damageReductionPercent(1e20, 2).summary.contains("\(Int.max)%"))
        #expect(Effect.healingReductionPercent(1e20, 2).summary.contains("\(Int.max)%"))
        let summary = try #require(EffectSummaryBuilder.build(for: battle.activeEffects(of: battle.hero)).first)
        #expect(summary.text.contains("+\(Int.max)%"))
    }

    private func makeBattle(profile: CombatModifierProfile) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 4),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20), heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
