import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct BattleArithmeticBoundaryTests {
    @Test(arguments: [Keyword.physical, .burn, .poison])
    func `large damage and equipment bonuses resolve the hit instead of overflowing`(keyword: Keyword) {
        var profile = CombatModifierProfile(damageDealtBonus: [.physical: 1], outgoingDamagePercent: 1)
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.burnCriticalDamageBonus = 1
        profile.triggers.poisonCriticalDamageBonus = 1
        profile.triggers.storedImpact = true
        var battle = makeBattle(profile: profile)
        battle.storedBlockedDamageByActorID[battle.hero.id] = Int.max
        battle.storedBlockedDamageByActorID[battle.companion.id] = Int.max
        var options = DamageOperation.attack(accuracy: .unavoidable, guaranteedCritical: true)
        options.capturesCardRepeat = true
        let outcome = battle.resolveTestDamage(Int.max, keyword: keyword, options: options)
        #expect(outcome.healthLost == 20)
        #expect(battle.isEnemyDefeated)
    }

    @Test func `Blood Offering retains its Health cost when outgoing damage saturates the summary`() {
        var profile = CombatModifierProfile(damageDealtBonus: [.bleed: Int.max])
        profile.triggers.criticalChanceBonus = -1
        var battle = makeBattle(profile: profile, enemyMaxHealth: Int.max)
        let events = battle.performTestAction(AbilityCatalog.bloodOffering)
        #expect(battle.health(of: battle.hero) == 18)
        #expect(battle.isEnemyDefeated)
        #expect(events.first { $0.kind == .ability }?.amount == Int.max)
    }

    @Test func `Mana restoration with a saturated bonus fills capacity without overflowing`() {
        var battle = makeBattle(profile: CombatModifierProfile(maximumManaBonus: Int.max, manaRestoredBonus: Int.max))
        let restored = battle.restoreMana(1, to: battle.hero)
        #expect(restored == Int.max)
        #expect(battle.mana(of: battle.hero) == Int.max)
    }

    @Test func `Gold grants saturate the ledger and report only the recorded gain`() {
        var battle = makeBattle(profile: CombatModifierProfile(goldGainedBonus: 1), heroMaxHealth: Int.max)
        let first = battle.recordingEvents { battle in _ = await battle.grantGold(Int.max, to: battle.hero, abilityName: "Gold") }
        let second = battle.recordingEvents { battle in _ = await battle.grantGold(1, to: battle.hero, abilityName: "Gold") }
        #expect(battle.gold == Int.max)
        #expect(battle.goldFlow.gained == Int.max)
        #expect(first.first?.amount == Int.max)
        #expect(second.first?.amount == 0)
    }

    @Test func `Block at capacity admits only the available gain`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockRetainsThreeQuarters = true
        var battle = makeBattle(profile: profile)
        DefensePoolEngine.set(Int.max - 1, on: battle.hero, in: &battle)
        let gained = DefensePoolEngine.add(10, to: battle.hero, in: &battle)
        let full = DefensePoolEngine.add(1, to: battle.hero, in: &battle)
        #expect(gained == 1)
        #expect(full == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == Int.max)
        CombatExecutor.run { await DefensePoolEngine.decayBlock(on: battle.hero, in: &battle) }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 6917529027641081855)
    }

    @Test func `large control damage completes existing buildup without overflowing`() {
        var battle = makeBattle()
        battle.insertEffect(.controlMeter(.stun, 3, 4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let events = battle.chargeTestControl(Int.max, keyword: .stun, to: battle.enemy, sourceActorID: nil, applyFightPacing: false)
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    @Test func `Block grants with a saturated flat bonus fill capacity without overflowing`() {
        var battle = makeBattle(profile: CombatModifierProfile(blockGainedBonus: Int.max))
        let gain = battle.applyBlockGain(1, to: battle.hero, source: battle.hero, abilityName: "Block")
        #expect(gain == Int.max)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == Int.max)
    }

    @Test func `Freeze amplification saturates before applying the control threshold`() {
        var battle = makeBattle()
        battle.insertEffect(.controlMeter(.freeze, 2, 4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let events = battle.recordingEvents { battle in await ControlMeterEngine.multiplyBuildup(
            Int.max, keyword: .freeze, to: battle.enemy, sourceActorID: battle.hero.id,
            abilityName: "Cold Snap", in: &battle,
        ) }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
        #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    private func makeBattle(
        profile: CombatModifierProfile = .zero, heroMaxHealth: Int = 20, enemyMaxHealth: Int = 20,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: heroMaxHealth, maxMana: 4),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyMaxHealth),
            heroMana: 0, heroModifiers: profile, appliesFightPacing: false,
        )
    }

    @Test func `probability endpoints do not depend on random endpoint`() {
        var maximum = EndpointRandomNumberGenerator(value: .max)
        var minimum = EndpointRandomNumberGenerator(value: .min)

        #expect(BattleChance.succeeds(probability: 1, using: &maximum))
        #expect(!BattleChance.succeeds(probability: 0, using: &minimum))
        #expect(BattleChance.succeeds(probability: 0.5, using: &minimum))
        #expect(!BattleChance.succeeds(probability: 0.5, using: &maximum))
    }
}

private struct EndpointRandomNumberGenerator: RandomNumberGenerator {
    let value: UInt64

    mutating func next() -> UInt64 {
        value
    }
}
