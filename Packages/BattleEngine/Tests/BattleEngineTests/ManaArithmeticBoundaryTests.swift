import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ManaArithmeticBoundaryTests {
    @Test func `Arcane Thorns combines with saturated Living Conduit overflow`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.livingConduit = true
        profile.triggers.arcaneThornsOnManaRestore = 1
        var battle = makeBattle(heroModifiers: profile)
        _ = battle.restoreMana(Int.max, to: battle.hero)
        _ = battle.restoreMana(4, to: battle.hero)
        #expect(battle.roster.hero.talents.pending.manaOverflowThorns == Int.max)
        _ = battle.payMana(1, for: battle.hero)

        let events = CombatExecutor.run {
            await battle.restoreManaEmitting(1, to: battle.hero, abilityName: "Restore")
        }

        #expect(battle.activeEffects(of: battle.hero).first { $0.effect.kind == .thorns }?.effect.potency == Int.max)
        #expect(events.contains { $0.amount == Int.max && $0.keyword == .thorns })
        #expect(battle.roster.hero.talents.pending.manaOverflowThorns == 0)
    }

    @Test(arguments: [false, true])
    func `Mana damage preparation saturates multiplication and accumulated bonus`(existingBonus: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.spendManaDamageBonusPerMana = existingBonus ? 1 : Int.max
        var battle = makeBattle(heroModifiers: profile)
        battle.roster.hero.currentMana = 4
        battle.roster.hero.talents.pending.cardDamageBonus = existingBonus ? Int.max : 0
        let payment = battle.payMana(3, for: battle.hero)

        _ = CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.hero.talents.pending.cardDamageBonus == Int.max)
    }

    @Test func `hero Mana spend saturates the companion's existing damage preparation`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHeroSpendManaCompanionNextAttackBonus = 1
        var battle = makeBattle(companionModifiers: profile)
        battle.roster.hero.currentMana = 4
        battle.roster.companion.talents.pending.cardDamageBonus = Int.max
        let payment = battle.payMana(1, for: battle.hero)

        _ = CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.companion.talents.pending.cardDamageBonus == Int.max)
    }

    @Test func `automatic Mana play retains exact excess when cumulative spending exceeds Int max`() {
        var profile = CombatModifierProfile(maximumManaBonus: Int.max)
        profile.triggers.spendManaThresholdAutoPlayCard = Int.max
        var battle = makeBattle(heroModifiers: profile)
        battle.roster.hero.currentMana = Int.max
        battle.roster.hero.talents.battle.manaSpentTowardAutoPlay = 1
        battle.heroDeck = CombatDeck(abilities: [.block])
        let payment = battle.payMana(Int.max, for: battle.hero)

        let events = CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == 1)
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == 1)
    }

    private func makeBattle(
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 4),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroMana: 0, heroModifiers: heroModifiers, companionModifiers: companionModifiers,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
