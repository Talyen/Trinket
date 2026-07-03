import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class EffectSummaryBuilderTests: XCTestCase {
    // MARK: - Decaying DoT priority

    func testBurnStackYieldsActiveSummary() {
        let effects = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.keyword, .burn)
        XCTAssertEqual(summaries.first?.text, "Burn active")
    }

    func testPoisonStackYieldsActiveSummary() {
        let effects = [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.keyword, .poison)
        XCTAssertEqual(summaries.first?.text, "Poison active")
    }

    // MARK: - Bleed totals

    func testBleedStacksSummed() {
        let effects = [
            ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 2),
            ActiveEffect(id: 2, effect: .bleed(2), remainingTicks: 1)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.text, "Bleed: 5 damage")
    }

    func testExpiredBleedNotSummed() {
        let effects = [
            ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .bleed(2), remainingTicks: 1)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        // Only the active one contributes; total = 2.
        XCTAssertEqual(summaries.first?.text, "Bleed: 2 damage")
    }

    // MARK: - Defensive totals

    func testShieldSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Block: 5 buffer, 6 ticks left.")
    }

    func testMitigationSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 3), remainingTicks: 3)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Armor: 25% mitigation, 3 ticks left.")
    }

    // MARK: - Prevention / build-up

    func testStunBuildupSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Stun Build-up: 3/10")
    }

    func testTriggeredStunBuildupSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Stunned: action prevented.")
    }

    func testPartialBuildupSummaryWhenBelowThreshold() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Freeze Build-up: 1/10")
    }

    func testStunAndFreezeBuildupSummariesAreSeparate() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.freeze, 5, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries.contains { $0.keyword == .stun && $0.text == "Stun Build-up: 3/10" })
        XCTAssertTrue(summaries.contains { $0.keyword == .freeze && $0.text == "Freeze Build-up: 5/10" })
    }

    // MARK: - Other tickable effects

    func testLeechSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .leech(.leech, 0.10, 6), remainingTicks: 6)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.first?.text, "Leech: 10% leech, 6 ticks left.")
    }

    // MARK: - Empty / no-summaries

    func testEmptyEffectsProducesEmptySummaries() {
        XCTAssertTrue(EffectSummaryBuilder.build(for: []).isEmpty)
    }

    func testInstantEffectsHaveNoSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .instantHeal(.health, 5), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .resourceGain(.gold, 3), remainingTicks: 0)
        ]
        XCTAssertTrue(EffectSummaryBuilder.build(for: effects).isEmpty)
    }

    // MARK: - Multi-keyword

    func testMultipleKeywordsYieldMultipleSummaries() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6),
            ActiveEffect(id: 2, effect: .mitigation(.armor, 0.25, 3), remainingTicks: 3)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries.contains { $0.keyword == .block })
        XCTAssertTrue(summaries.contains { $0.keyword == .armor })
    }
}
