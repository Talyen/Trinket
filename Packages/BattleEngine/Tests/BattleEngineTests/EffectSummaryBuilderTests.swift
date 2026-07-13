import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectSummaryBuilderTests {
    // MARK: - Decaying DoT priority

    @Test func burnStackYieldsActiveSummary() throws {
        let effects = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 1)
        try #expect(summaries.first?.keyword == .burn)
        try #expect(summaries.first?.text == "Burn active")
    }

    // MARK: - Bleed totals

    @Test func bleedStacksSummed() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 2),
            ActiveEffect(id: 2, effect: .bleed(2), remainingTicks: 1)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 1)
        try #expect(summaries.first?.text == "Bleed: 5 damage")
    }

    // MARK: - Defensive totals

    @Test func shieldSummary() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.first?.text == "Block: 5.")
    }

    // MARK: - Prevention / build-up

    @Test func stunBuildupAndTriggeredSummaries() throws {
        let buildup = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0)
        ])
        try #expect(buildup.first?.text == "Stun Build-up: 3/10")

        let triggered = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        try #expect(triggered.first?.text == "Stunned: action prevented.")
    }

    // MARK: - Other tickable effects

    @Test func leechSummary() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .leech(.leech, 0.10, 6), remainingTicks: 6)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.first?.text == "Leech: 10% leech, 6 turns left.")
    }

    @Test func deathsDoorSummary() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .deathsDoor, remainingTicks: BattleTiming.deathsDoorDurationTicks)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 1)
        try #expect(summaries.first?.keyword == .deathsDoor)
        try #expect(
            summaries.first?.text == "Death's Door: heal soon or the next fatal blow will end them."
        )
    }

    // MARK: - Empty / no-summaries

    @Test func emptyEffectsProducesEmptySummaries() throws {
        try #expect(EffectSummaryBuilder.build(for: []).isEmpty)
    }

    // MARK: - Multi-keyword

    @Test func multipleKeywordsYieldMultipleSummaries() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
            ActiveEffect(id: 2, effect: .mitigation(.armor, 2), remainingTicks: 3)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 2)
        try #expect(summaries.contains { $0.keyword == .block })
        try #expect(summaries.contains { $0.keyword == .armor })
    }
}
