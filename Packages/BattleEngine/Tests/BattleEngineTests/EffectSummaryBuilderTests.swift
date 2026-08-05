import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectSummaryBuilderTests {
    private enum SingleKeywordCase {
        case burnActive
        case bleedStacks
        case shield
        case leech
        case deathsDoor
    }

    @Test(arguments: [
        SingleKeywordCase.burnActive,
        .bleedStacks,
        .shield,
        .leech,
        .deathsDoor,
    ])
    private func singleKeywordSummary(caseKind: SingleKeywordCase) throws {
        let effects: [ActiveEffect]
        let expectedText: String
        let expectedKeyword: Keyword?
        switch caseKind {
        case .burnActive:
            effects = [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)]
            expectedText = "Burn active"
            expectedKeyword = .burn
        case .bleedStacks:
            effects = [
                ActiveEffect(id: 1, effect: .bleed(3), remainingTurns: 2),
                ActiveEffect(id: 2, effect: .bleed(2), remainingTurns: 1),
            ]
            expectedText = "Bleed: 5 damage"
            expectedKeyword = nil
        case .shield:
            effects = [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)]
            expectedText = "Block: 5."
            expectedKeyword = nil
        case .leech:
            effects = [ActiveEffect(id: 1, effect: .leech(.leech, 0.10, 6), remainingTurns: 6)]
            expectedText = "Leech: 10% leech, 6 turns left."
            expectedKeyword = nil
        case .deathsDoor:
            effects = [
                ActiveEffect(
                    id: 1,
                    effect: .deathsDoor,
                    remainingTurns: BattleTiming.deathsDoorDurationTurns
                ),
            ]
            expectedText = "Death's Door: heal soon or the next fatal blow will end them."
            expectedKeyword = .deathsDoor
        }

        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 1)
        try #expect(summaries.first?.text == expectedText)
        if let expectedKeyword {
            try #expect(summaries.first?.keyword == expectedKeyword)
        }
    }

    @Test func stunBuildupAndTriggeredSummaries() throws {
        let buildup = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTurns: 0),
        ])
        try #expect(buildup.first?.text == "Stun Build-up: 3/10")

        let triggered = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
        ])
        try #expect(triggered.first?.text == "Stunned: action prevented.")

        let lingered = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1),
        ])
        try #expect(lingered.first?.text == "Stunned")
    }

    @Test func emptyEffectsProducesEmptySummaries() throws {
        try #expect(EffectSummaryBuilder.build(for: []).isEmpty)
    }

    @Test func multipleKeywordsYieldMultipleSummaries() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
            ActiveEffect(id: 2, effect: .burn(2), remainingTurns: 3),
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 2)
        try #expect(summaries.contains { $0.keyword == .block })
        try #expect(summaries.contains { $0.keyword == .burn })
    }
}
