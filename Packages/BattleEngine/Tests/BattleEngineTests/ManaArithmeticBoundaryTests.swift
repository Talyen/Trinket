import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

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

        let events = battle.recordingEvents { battle in
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

        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.hero.talents.pending.cardDamageBonus == Int.max)
    }

    @Test func `hero Mana spend saturates the companion's existing damage preparation`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHeroSpendManaCompanionNextAttackBonus = 1
        var battle = makeBattle(companionModifiers: profile)
        battle.roster.hero.currentMana = 4
        battle.roster.companion.talents.pending.cardDamageBonus = Int.max
        let payment = battle.payMana(1, for: battle.hero)

        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

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

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == 1)
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == 1)
    }

    @Test(arguments: [false, true])
    func `oversized Mana automatic play stops after its deck is exhausted`(hasCard: Bool) {
        var profile = CombatModifierProfile(maximumManaBonus: Int.max)
        profile.triggers.spendManaThresholdAutoPlayCard = 3
        var battle = makeBattle(heroModifiers: profile)
        battle.roster.hero.currentMana = Int.max
        battle.roster.hero.talents.battle.manaSpentTowardAutoPlay = 1
        battle.heroDeck = CombatDeck(abilities: hasCard ? [.block] : [])
        let payment = battle.payMana(Int.max, for: battle.hero)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }

        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == 2)
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == (hasCard ? 1 : 0))
        #expect(battle.heroDeck.abilities.isEmpty)
        #expect(!battle.resolution.isAutomaticPlay)
    }

    private func makeBattle(
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 4),
            heroMana: 0, heroModifiers: heroModifiers, companionModifiers: companionModifiers, appliesFightPacing: false,
        )
    }
}
