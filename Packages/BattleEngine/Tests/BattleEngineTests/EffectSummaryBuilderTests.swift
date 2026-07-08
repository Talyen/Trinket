import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct EffectSummaryBuilderTests {
    // MARK: - Decaying DoT priority

    @Test func burnStackYieldsActiveSummary() {
        let effects = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.count == 1)
        #expect(summaries.first?.keyword == .burn)
        #expect(summaries.first?.text == "Burn active")
    }

    @Test func poisonStackYieldsActiveSummary() {
        let effects = [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.keyword == .poison)
        #expect(summaries.first?.text == "Poison active")
    }

    // MARK: - Bleed totals

    @Test func bleedStacksSummed() {
        let effects = [
            ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 2),
            ActiveEffect(id: 2, effect: .bleed(2), remainingTicks: 1)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.count == 1)
        #expect(summaries.first?.text == "Bleed: 5 damage")
    }

    @Test func expiredBleedNotSummed() {
        let effects = [
            ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .bleed(2), remainingTicks: 1)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        // Only the active one contributes; total = 2.
        #expect(summaries.first?.text == "Bleed: 2 damage")
    }

    // MARK: - Defensive totals

    @Test func shieldSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Block: 5 buffer, 6 ticks left.")
    }

    @Test func mitigationSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 3), remainingTicks: 3)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Armor: 25% mitigation, 3 ticks left.")
    }

    // MARK: - Prevention / build-up

    @Test func stunBuildupSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Stun Build-up: 3/10")
    }

    @Test func triggeredStunBuildupSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Stunned: action prevented.")
    }

    @Test func partialBuildupSummaryWhenBelowThreshold() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Freeze Build-up: 1/10")
    }

    @Test func stunAndFreezeBuildupSummariesAreSeparate() {
        let effects = [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.freeze, 5, 10), remainingTicks: 0)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.count == 2)
        #expect(summaries.contains { $0.keyword == .stun && $0.text == "Stun Build-up: 3/10" })
        #expect(summaries.contains { $0.keyword == .freeze && $0.text == "Freeze Build-up: 5/10" })
    }

    // MARK: - Other tickable effects

    @Test func leechSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .leech(.leech, 0.10, 6), remainingTicks: 6)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.first?.text == "Leech: 10% leech, 6 ticks left.")
    }

    @Test func deathsDoorSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .deathsDoor, remainingTicks: BattleTiming.deathsDoorDurationTicks)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.count == 1)
        #expect(summaries.first?.keyword == .deathsDoor)
        #expect(
            summaries.first?.text == "Death's Door: heal soon or the next fatal blow will end them."
        )
    }

    // MARK: - Empty / no-summaries

    @Test func emptyEffectsProducesEmptySummaries() {
        #expect(EffectSummaryBuilder.build(for: []).isEmpty)
    }

    @Test func instantEffectsHaveNoSummary() {
        let effects = [
            ActiveEffect(id: 1, effect: .instantHeal(.health, 5), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .resourceGain(.gold, 3), remainingTicks: 0)
        ]
        #expect(EffectSummaryBuilder.build(for: effects).isEmpty)
    }

    // MARK: - Multi-keyword

    @Test func multipleKeywordsYieldMultipleSummaries() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6),
            ActiveEffect(id: 2, effect: .mitigation(.armor, 0.25, 3), remainingTicks: 3)
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        #expect(summaries.count == 2)
        #expect(summaries.contains { $0.keyword == .block })
        #expect(summaries.contains { $0.keyword == .armor })
    }
}
