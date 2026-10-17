import Foundation
import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct BattleBoundaryRegressionTests {
    @Test func `combined Companion draw bonuses saturate and draw only available cards`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: .withTriggers {
            $0.companionCardsPerTurn = Int.max
            $0.companionCardsEveryOtherTurn = 1
        }, appliesFightPacing: false)
        battle.companionDeck = CombatDeck(abilities: [.slash, .block])

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.hand.totalCount == 2)
        #expect(events.filter { $0.effectKind == .cardsDrawn }.map(\.amount) == [2])
    }

    @Test func `combined personal and party damage bonuses saturate before the hit`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.damageWhileTargetFrozenBonus = Int.max
        profile.triggers.partyDamageBonusWhileCompanionFullHealth = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = makeBattle(profile: profile)
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(.controlMeter(.freeze, threshold, threshold), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let outcome = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable))

        #expect(outcome.healthLost == 20)
        #expect(battle.isEnemyDefeated)
    }

    @Test func `stacked readied attack bonuses saturate when combined with battle bonuses`() {
        var battle = makeBattle(profile: .withTriggers { $0.criticalChanceBonus = -1 })
        battle.roster.hero.talents.pending.nextHitBonus = Int.max
        battle.roster.hero.talents.pending.attackBonusOnFullHealth = PreparedTalentBonus(value: 1)
        battle.roster.hero.talents.battle.damageBonus = 1

        let outcome = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable))

        #expect(outcome.healthLost == 20)
        #expect(battle.isEnemyDefeated)
        #expect(battle.roster.hero.talents.pending.nextHitBonus == 0)
        #expect(battle.roster.hero.talents.pending.attackBonusOnFullHealth == nil)
    }

    @Test(arguments: [false, true])
    func `prepared flat attack bonuses saturate the outgoing packet`(holy: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.firstHolyAttackBonusPerTurn = holy ? Int.max : 0
        var battle = makeBattle(profile: profile)
        if !holy {
            battle.roster.hero.talents.pending.nextManaSpendAttackBonus = PreparedTalentBonus(value: Int.max)
        }

        let outcome = battle.resolveTestDamage(1, keyword: .holy, options: .attack(accuracy: .unavoidable))

        #expect(outcome.healthLost == 20)
        #expect(battle.isEnemyDefeated)
    }

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
        let nextPayment = budget.nextPayment()
        let payment = try #require(nextPayment)
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
        battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        CombatExecutor.run { await BattleTurnEngine.applyDoTStackFromDamage(
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

    @Test func `maximum Mana at capacity emits no restoration feedback`() {
        var battle = makeBattle(profile: CombatModifierProfile(maximumManaBonus: Int.max))
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = Int.max }
        let outcome = EffectHandlersTestSupport.dispatch(.maximumManaBonus(1), battle: &battle)
        #expect(!outcome.events.contains { $0.effectKind == .resourceGain })
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
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
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

        battle.roster.hero.talents.pending.doubleNextGoldSteal = true
        let gain = battle.recordingResult { battle in await battle.grantGold(
            atCapacity ? 1 : 0, to: battle.hero, abilityName: "Gold", isTheft: true,
        ) }

        #expect(gain.value == 0)
        #expect(battle.health(of: battle.hero) == 10)
        #expect(gain.events.isEmpty)
        #expect(battle.roster.hero.talents.pending.doubleNextGoldSteal)
        if !atCapacity {
            battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
            #expect(battle.health(of: battle.hero) == 12)
        }
    }

    @Test func `party Mana summaries saturate without reducing either recipient's gain`() throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: Int.max),
            companion: CombatantFixtures.passiveCompanion(maxMana: Int.max),
            enemy: CombatantFixtures.passiveEnemy(), heroMana: 0, companionMana: 0, appliesFightPacing: false,
        )
        let ability = Ability(
            id: "party-mana", name: "Party Mana", tier: .skill,
            operations: [.effect(TargetedEffect(.resourceGain(.mana, Int.max), target: .eachAlly))],
        )

        let events = battle.performTestAction(ability)

        #expect(battle.mana(of: battle.hero) == Int.max)
        #expect(battle.mana(of: battle.companion) == Int.max)
        #expect(events.filter { $0.effectKind == .resourceGain }.map(\.amount) == [Int.max, Int.max])
        let summary = try #require(events.last { $0.kind == .ability })
        #expect(summary.appliedEffects == [.resourceGain(.mana, Int.max)])
    }

    @Test func `Holy damage preparations preserve saturated bonuses`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.holyDamageNextHitBonus = 1
        profile.triggers.holyDamageNextAttackHolyBonus = 1
        var battle = makeBattle(profile: profile)
        battle.roster.hero.talents.pending.nextHitBonus = Int.max
        battle.roster.hero.talents.pending.nextAttackHolyBonus = Int.max

        CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(
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
        let locale = Locale(identifier: "en")
        for (effect, valueID) in [
            (Effect.criticalChanceBonus(1e20, 2), "chance"),
            (.damageReductionPercent(1e20, 2), "percent"),
            (.healingReductionPercent(1e20, 2), "percent"),
        ] {
            let details = EffectPresentation.localizedDescription(for: effect, locale: locale)
            #expect(details.values[valueID] == Int.max)
        }
        let ability = Ability(id: "large-critical", name: "Large Critical", tier: .skill, criticalChanceBonus: 1e20)
        // Reading card details previously converted this percentage to Int without saturation.
        #expect(ability.generatedDescription.contains("% Critical chance"))
        let summary = try #require(EffectSummaryBuilder.build(for: battle.activeEffects(of: battle.hero)).first)
        let displayedMaximum = Int.max.formatted(.number.locale(Locale(identifier: "en")))
        #expect(summary.text.contains("+\(displayedMaximum)%"))
    }

    @Test func `stacked Burn potency saturates before damage bonuses read it`() {
        var battle = makeBattle(profile: .zero)
        for potency in [Int.max, 1] {
            battle.insertEffect(.burn(potency), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        #expect(CombatTriggerEngine.totalPotency(of: .burn, on: battle.enemy, in: battle) == Int.max)
    }

    @Test func `critical Bleed extensions cap before duration multiplication can overflow`() throws {
        var battle = makeBattle(profile: .withTriggers { $0.onCritDoubleBleedDuration = true })
        battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: Int.max)

        CombatExecutor.run { await CombatTriggerEngine.afterCriticalHit(
            to: battle.enemy, source: battle.hero, targetWasStunnedAtHit: false, in: &battle,
        ) }

        let bleed = try #require(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed })
        #expect(bleed.remainingTurns == 10)
    }

    @Test(arguments: [0, 10])
    func `damage ramps safely apply capped and uncapped growth at integer limits`(cap: Int) {
        var profile = CombatModifierProfile.zero
        profile.triggers.burnDamageRampPerRound = Int.max
        profile.triggers.burnDamageRampCap = cap
        profile.triggers.bleedDamageRampPerRound = Int.max
        profile.triggers.bleedDamageRampCap = cap
        var battle = makeBattle(profile: profile)
        battle.roster.hero.talents.battle.keywordDamageRamp = [.burn: 1, .bleed: 1]

        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        for keyword in [Keyword.burn, .bleed] {
            #expect(battle.roster.hero.talents.battle.keywordDamageRamp[keyword] == (cap > 0 ? cap : Int.max))
        }
    }

    @Test func `Stun purge damage resolves multiple removed buffs without overflowing`() {
        var battle = makeBattle(profile: .withTriggers { $0.stunPurgeDealHolyPerEffect = Int.max })
        battle.insertEffect(.shield(.block, 1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        CombatExecutor.run { await CombatTriggerEngine.afterEnemyStunned(
            sourceActorID: battle.hero.id, in: &battle,
        ) }

        #expect(battle.isEnemyDefeated)
        #expect(battle.activeEffects(of: battle.enemy).isEmpty)
    }

    @Test func `Stored Impact continues absorbing damage at accumulated capacity`() {
        var battle = makeBattle(profile: .withTriggers { $0.storedImpact = true })
        battle.roster.hero.talents.battle.storedBlockedDamage = Int.max
        DefensePoolEngine.set(2, on: battle.hero, in: &battle)

        let outcome = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .reaction())

        #expect(outcome.healthLost == 0)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(battle.roster.hero.talents.battle.storedBlockedDamage == Int.max)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 1)
    }

    @Test func `Gilded Claws retains a saturated preparation when more Gold arrives`() {
        var battle = makeBattle(profile: .withTriggers { $0.gildedClaws = true })
        battle.roster.hero.talents.history.stolenGoldDamage = Int.max
        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Steal", isTheft: true)
        #expect(battle.gold == 1)
        #expect(battle.roster.hero.talents.history.stolenGoldDamage == Int.max)
    }

    private func makeBattle(profile: CombatModifierProfile) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 4),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20), heroModifiers: profile, appliesFightPacing: false,
        )
    }
}
