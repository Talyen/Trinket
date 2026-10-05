import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

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
        let outcome = battle.resolveDamage(DamageRequest(
            amount: Int.max, target: battle.enemy, keyword: keyword,
            sourceActorID: battle.hero.id, options: options,
        ))
        #expect(outcome.healthLost == 20)
        #expect(battle.isEnemyDefeated)
    }

    @Test func `Mana restoration with a saturated bonus fills capacity without overflowing`() {
        var battle = makeBattle(profile: CombatModifierProfile(maximumManaBonus: Int.max, manaRestoredBonus: Int.max))
        let restored = battle.restoreMana(1, to: battle.hero)
        #expect(restored == Int.max)
        #expect(battle.mana(of: battle.hero) == Int.max)
    }

    @Test func `Gold grants saturate the ledger and report only the recorded gain`() {
        var battle = makeBattle(profile: CombatModifierProfile(goldGainedBonus: 1), heroMaxHealth: Int.max)
        let first = battle.grantGoldEvent(Int.max, to: battle.hero, abilityName: "Gold")
        let second = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
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
        _ = DefensePoolEngine.decayBlock(on: battle.hero, in: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 6917529027641081855)
    }

    @Test func `large control damage completes existing buildup without overflowing`() {
        var battle = makeBattle()
        battle.appendEffect(.controlMeter(.stun, 3, 4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let events = ControlMeterEngine.applyMeterCharge(
            Int.max, keyword: .stun, to: battle.enemy, sourceActorID: nil,
            applyFightPacing: false, in: &battle,
        )
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    private func makeBattle(profile: CombatModifierProfile = .zero, heroMaxHealth: Int = 20) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: heroMaxHealth, maxMana: 4),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroMana: 0, heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
