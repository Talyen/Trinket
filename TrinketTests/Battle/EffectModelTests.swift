@testable import Trinket
import XCTest

final class EffectModelTests: XCTestCase {
    func testDamageOverTimeEffect() {
        let effect = Effect.damageOverTime(.poison, 2, 3)
        XCTAssertEqual(effect.keyword, .poison)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Poison 2 for 3 ticks")
    }

    func testPreventionEffect() {
        let effect = Effect.prevention(.stun, 2)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 2)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Stun for 2 actions")
    }

    func testShieldEffect() {
        let effect = Effect.shield(.block, 5, 3)
        XCTAssertEqual(effect.keyword, .block)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Block 5 for 3 ticks")
    }

    func testMitigationEffect() {
        let effect = Effect.mitigation(.armor, 0.25, 3)
        XCTAssertEqual(effect.keyword, .armor)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Armor 25% for 3 ticks")
    }

    func testInstantHealEffect() {
        let effect = Effect.instantHeal(.health, 5)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "Health 5")
    }

    func testLeechEffect() {
        let effect = Effect.leech(.leech, 0.25, 3)
        XCTAssertEqual(effect.keyword, .leech)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Leech 25% for 3 ticks")
    }

    func testResourceGainEffect() {
        let effect = Effect.resourceGain(.gold, 3)
        XCTAssertEqual(effect.keyword, .gold)
        XCTAssertEqual(effect.durationTicks, 0)
        XCTAssertTrue(effect.isInstant)
        XCTAssertEqual(effect.summary, "Gold 3")
    }

    func testCleanseSpecificEffect() {
        let effect = Effect.cleanse(.stun, 3)
        XCTAssertEqual(effect.keyword, .stun)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Cleanse Stun for 3 ticks")
    }

    func testCleanseAllEffect() {
        let effect = Effect.cleanse(nil, 3)
        XCTAssertEqual(effect.keyword, .health)
        XCTAssertEqual(effect.durationTicks, 3)
        XCTAssertFalse(effect.isInstant)
        XCTAssertEqual(effect.summary, "Cleanse all for 3 ticks")
    }

    func testActiveEffectTracksRemainingTicks() {
        let effect = Effect.damageOverTime(.burn, 1, 3)
        var active = ActiveEffect(id: 1, effect: effect, remainingTicks: 3)
        XCTAssertEqual(active.keyword, .burn)
        active.remainingTicks -= 1
        XCTAssertEqual(active.remainingTicks, 2)
    }

    func testEffectSummaryKeywords() {
        let summaries = [
            EffectSummary(keyword: .burn, text: "Burn: 2 damage next tick, 1 stack."),
            EffectSummary(keyword: .block, text: "Block: 5 buffer, 2 ticks left."),
            EffectSummary(keyword: .stun, text: "Stun: 1 actions prevented.")
        ]
        for summary in summaries {
            XCTAssertEqual(summary.id, summary.keyword)
        }
    }

    func testAbilityHasNoEffectsByDefault() {
        let ability = Ability(id: "test", name: "Test", tier: .basic, directDamage: 1)
        XCTAssertTrue(ability.effects.isEmpty)
        XCTAssertNil(ability.statusApplication)
        XCTAssertEqual(ability.damageKeyword, .physical)
    }

    func testAbilityWithEffects() {
        let ability = Ability(id: "test-dot", name: "Test DOT", tier: .skill, directDamage: 3, damageKeyword: .poison, effects: [.damageOverTime(.poison, 1, 2)])
        XCTAssertEqual(ability.effects.count, 1)
        XCTAssertEqual(ability.damageKeyword, .poison)
        XCTAssertEqual(ability.damage, 3)
        XCTAssertEqual(ability.damageType, .poison)
    }

    func testAbilityKeywordsIncludeEffects() {
        let ability = Ability(id: "test-kw", name: "Test KW", tier: .basic, directDamage: 1, effects: [.instantHeal(.health, 2)])
        let kws = ability.keywords
        XCTAssertTrue(kws.contains(.physical))
        XCTAssertTrue(kws.contains(.health))
    }

    func testAbilitySummaryWithEffects() {
        let ability = Ability(id: "test-summary", name: "Test", tier: .basic, directDamage: 2, damageKeyword: .holy, statusApplication: nil, effects: [.damageOverTime(.burn, 1, 2)])
        XCTAssertTrue(ability.summary.contains("2 Holy damage"))
        XCTAssertTrue(ability.summary.contains("Burn 1 for 2 ticks"))
    }
}
