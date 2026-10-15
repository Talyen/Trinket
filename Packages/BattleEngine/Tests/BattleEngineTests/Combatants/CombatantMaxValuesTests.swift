import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatantMaxValuesTests {
    @Test func `party level scaling preserves extreme saved levels without overflowing stats`() {
        let hero = CombatantFixtures.passiveHero(maxHealth: 20, maxMana: Int.max)
        let scaled = CombatantLevelScaler.scale(combatant: hero, level: Int.max)
        #expect(scaled.maxHealth == Int.max)
        #expect(scaled.maxMana == Int.max)
        let invalid = CombatantLevelScaler.scale(combatant: hero, level: Int.min)
        #expect(invalid.maxHealth == hero.maxHealth)
        #expect(invalid.maxMana == hero.maxMana)
    }

    @Test func `maximum mana percent scales combatants with mana and leaves zero mana unchanged`() {
        let heroWithMana = CombatantFixtures.passiveHero(maxMana: 20)
        #expect(heroWithMana.hasMana)

        let modifiers = CombatModifierProfile(maximumManaPercentBonus: 0.20)
        let scaledMana = CombatantMaxValues.maxMana(for: heroWithMana, modifiers: modifiers)
        #expect(scaledMana == 24)

        let heroNoMana = CombatantFixtures.passiveHero(maxMana: 0)
        #expect(!heroNoMana.hasMana)
        let zeroMana = CombatantMaxValues.maxMana(for: heroNoMana, modifiers: modifiers)
        #expect(zeroMana == 0)
    }

    @Test func `maximum stats saturate overflowing flat bonuses`() {
        let hero = CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 20)
        let modifiers = CombatModifierProfile(maximumHealthBonus: .max, maximumManaBonus: .max)
        #expect(CombatantMaxValues.maxHealth(for: hero, modifiers: modifiers) == Int.max)
        #expect(CombatantMaxValues.maxMana(for: hero, modifiers: modifiers) == Int.max)
        #expect(CombatantMaxValues.maxHealth(for: hero, flatBonus: .max, talentBonus: 1) == Int.max)
        #expect(CombatantMaxValues.maxMana(for: hero, flatBonus: .max, effectBonus: 1) == Int.max)
        let stacks = [
            ActiveEffect(id: 1, effect: .maximumManaBonus(Int.max), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .maximumManaBonus(1), remainingTurns: 0),
        ]
        #expect(CombatantRuntime(combatant: hero, initialActiveEffects: stacks).maxMana == Int.max)
        #expect(EffectSummaryBuilder.build(for: stacks).first?.text.contains(String(Int.max)) == true)
    }

    @Test(arguments: [
        (20, 4, 0.5, 36, 39),
        (20, 4, -0.5, 12, 15),
        (20, 4, -2.0, 0, 3),
        (0, 4, 0.5, 0, 0),
        (2, Int.max, 1.0, Int.max, Int.max),
    ])
    func `party battles start with build mana and add active effect capacity`(
        baseMana: Int, flatBonus: Int, percentBonus: Double, startingMana: Int, capacity: Int,
    ) {
        let modifiers = CombatModifierProfile(maximumManaBonus: flatBonus, maximumManaPercentBonus: percentBonus)
        let effects = [ActiveEffect(id: 1, effect: .maximumManaBonus(3), remainingTurns: 2)]
        let state = BattleState(
            hero: CombatantFixtures.passiveHero(maxMana: baseMana),
            companion: CombatantFixtures.passiveCompanion(maxMana: baseMana),
            activeHeroEffects: effects,
            activeCompanionEffects: effects,
            heroModifiers: modifiers,
            companionModifiers: modifiers,
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentMana == startingMana)
        #expect(state.roster.companion.currentMana == startingMana)
        #expect(state.roster.hero.maxMana == capacity)
        #expect(state.roster.companion.maxMana == capacity)
    }

    @Test(arguments: [(0.25, 3), (-2.0, 0), (Double.greatestFiniteMagnitude / 4, Int.max), (Double.infinity, 0)])
    func `maximum mana uses safe combat rounding`(percent: Double, expected: Int) {
        let hero = CombatantFixtures.passiveHero(maxMana: 2)
        let modifiers = CombatModifierProfile(maximumManaPercentBonus: percent)
        #expect(CombatantMaxValues.maxMana(for: hero, modifiers: modifiers) == expected)
    }
}
