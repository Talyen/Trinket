import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingGainBoundaryTests {
    @Test func `flat healing talents preserve a saturated restoration`() {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_health_t1_1"])
        profile.healthRestoredBonus = Int.max
        profile.triggers.firstHealthRestorationBonusPerTurn = 2
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: Int.max),
            heroHealth: 1, heroModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.hero.id))

        #expect(outcome.healthRestored == Int.max - 1)
        #expect(battle.health(of: battle.hero) == Int.max)
    }

    @Test func `maximum Health conversion spends only the remaining capacity`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.overhealConvertsToMaxHealth = true
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: Int.max - 1),
            heroModifiers: profile, appliesFightPacing: false,
        )

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(
            HealRequest(amount: 3, target: battle.hero, sourceActorID: battle.hero.id), in: &battle,
        ) }

        #expect(battle.maxHealth(of: battle.hero) == Int.max)
        #expect(battle.health(of: battle.hero) == Int.max)
        #expect(result.allocation.maximumHealth == 1)
        #expect(result.allocation.remaining == 2)
    }

    @Test(arguments: [false, true])
    func `healing with a saturated flat bonus fills available Health without overflowing`(critical: Bool) throws {
        var profile = CombatModifierProfile(healthRestoredBonus: Int.max)
        profile.triggers.criticalChanceBonus = critical ? 1 : -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: Int.max),
            heroHealth: 1, heroModifiers: profile, appliesFightPacing: false,
        )
        if critical {
            let seed = try #require((UInt64(0) ..< 32).first { seed in
                var rng = SeededRandomNumberGenerator(seed: seed)
                return BattleChance.succeeds(probability: 0.75, using: &rng)
            })
            battle.rng = SeededRandomNumberGenerator(seed: seed)
        }
        let result = battle.resolveHeal(HealRequest(
            amount: 1, target: battle.hero, sourceActorID: battle.hero.id, origin: .restoration(.health),
        ))
        #expect(battle.health(of: battle.hero) == Int.max)
        #expect(result.healthRestored == Int.max - 1)
        #expect(result.isCritical == critical)
    }

    @Test func `Flawless Bounty grants Gold and Block without Windfall or nested restoration`() {
        var profile = CombatantTalentCatalog.profile(for: ["lizard_scout_gold_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.gainGoldBonusHealSelf = 2
        profile.triggers.goldGainHealChancePercent = 1
        profile.triggers.goldGainHealAmount = 3
        profile.triggers.goldGainBlockPercent = 1
        profile.triggers.goldGainCleanseChancePercent = 1
        profile.triggers.cleanseSelfHeal = 2
        profile.triggers.onHealDealHoly = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            companionModifiers: profile, appliesFightPacing: false,
        )
        battle.appendEffect(.poison(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 1)

        let result = CombatExecutor.run { await HealingEngine.leechFromDamage(
            8, sourceActorID: battle.companion.id, target: battle.enemy,
            abilityHasLeech: true, in: &battle,
        ) }

        #expect(battle.gold == 4)
        #expect(battle.health(of: battle.hero) == 10)
        #expect(battle.health(of: battle.companion) == 100)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 4)
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.isRemovableDebuff })
        #expect(result.events.contains { $0.abilityName == "Flawless Bounty" && $0.keyword == .gold && $0.amount == 4 })
        #expect(!result.events.contains { $0.effectKind == .instantHeal || $0.effectKind == .leechHeal })

        // Conversion suppression ends with its Gold transaction; ordinary gains still heal the wounded Hero.
        _ = battle.grantGoldEvent(1, to: battle.companion, abilityName: "Ordinary Gold")
        #expect(battle.health(of: battle.hero) == 15)
    }

    @Test(arguments: ["alchemist_health_t1_1", "druid_health_t1_1"], [0.25, 1.0])
    func `Sapped reduces the complete restoration including flat talent bonuses`(talent: String, reduction: Double) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: [talent]),
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t1_1"]), appliesFightPacing: false,
        )
        battle.appendEffect(.thorns(1), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        battle.appendEffect(.healingReductionPercent(reduction, 2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)

        let outcome = battle.resolveHeal(HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id))

        // Eight base Health plus two from Sprite Touch and two from the Hero's talent.
        let restored = reduction == 1 ? 0 : 9
        #expect(outcome.healthRestored == restored)
        #expect(battle.health(of: battle.hero) == 10 + restored)
        if reduction == 1 {
            battle.roster.hero.activeEffects.removeAll { $0.effect.kind == .healingReductionPercent }
            let later = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.companion.id))
            #expect(later.healthRestored == 5)
        }
    }

    @Test(arguments: [false, true])
    func `resolved Block preserves its amount and does not spend a prepared gain`(resolved: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            companionHealth: 10,
            companionModifiers: CombatantTalentCatalog
                .profile(for: ["bear_block_t3_2"]), appliesFightPacing: false,
        )
        battle.roster.companion.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)

        let gain = battle.applyBlockGain(
            4, to: battle.companion, source: battle.hero, abilityName: "Sunwall",
            amountBasis: resolved ? .resolved : .base,
        )

        #expect(gain.applied == (resolved ? 4 : 12))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == gain.applied)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier?.value == (resolved ? 2 : nil))
    }

    @Test(arguments: [false, true], [0, 8, 10])
    func `Soul Drain shares before restoring resolved Mana and converts only unused overflow`(leech: Bool, mana: Int) {
        var profile = CombatModifierProfile.zero
        profile.triggers.excessLeechRestoresMana = true
        profile.triggers.leechOverhealTransfersToCompanion = true
        profile.triggers.providedOverhealConvertsToBlock = true
        profile.manaRestoredBonus = 7
        profile.manaRestoredPercent = 1
        profile.triggers.manaGainDoubleChancePercent = 1
        profile.triggers.gainManaBlockFlat = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 10, heroMaxMana: 10,
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 7
        battle.roster.hero.currentMana = mana
        var request = HealRequest(
            amount: 10, target: battle.hero, sourceActorID: battle.hero.id,
            origin: leech ? .leech : .restoration(.health), logAs: .silent,
        )
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        let restoredMana = leech ? min(7, 10 - mana) : 0
        let convertedBlock = leech ? 7 - restoredMana : 10
        #expect(result.allocation.transferred == (leech ? 3 : 0))
        #expect(result.allocation.mana == restoredMana)
        #expect(result.allocation.block == convertedBlock)
        #expect(result.allocation.remaining == 0)
        #expect(battle.roster.hero.currentMana == mana + restoredMana)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == convertedBlock + (restoredMana > 0 ? 2 : 0))
        #expect(result.events.filter { $0.keyword == .mana }.map(\.amount) == (restoredMana > 0 ? [restoredMana] : []))
    }

    @Test(arguments: [false, true], [false, true])
    func `healer owned overflow conversion shares first and respects living ownership`(full: Bool, alive: Bool) {
        var sourceProfile = CombatModifierProfile.zero
        sourceProfile.triggers.sharedPrescription = true
        sourceProfile.triggers.providedOverhealConvertsToBlock = full
        sourceProfile.triggers.providedOverhealToBlockPercent = 0.5
        sourceProfile.blockGainedBonus = 9
        var targetProfile = CombatModifierProfile.zero
        targetProfile.triggers.overhealToBlockPercent = 0.25
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 10,
            heroModifiers: sourceProfile, companionModifiers: targetProfile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = alive ? battle.roster.hero.maxHealth - 2 : 0
        var request = HealRequest(amount: 10, target: battle.companion, sourceActorID: battle.hero.id)
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(result.allocation.transferred == (alive ? 2 : 0))
        #expect(result.allocation.block == (alive ? (full ? 8 : 4) : 3))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == result.allocation.block)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
    }
}
