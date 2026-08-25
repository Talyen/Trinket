import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectSummaryBuilderTests {
    private enum SingleKeywordCase {
        case burnActive
        case bleedStacks
        case shield
        case deathsDoor
    }

    @Test(arguments: [
        SingleKeywordCase.burnActive,
        .bleedStacks,
        .shield,
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
        case .deathsDoor:
            effects = [
                ActiveEffect(
                    id: 1,
                    effect: .deathsDoor,
                    remainingTurns: BattleTiming.deathsDoorDurationTurns
                ),
            ]
            expectedText = "Death's Door: immune to fatal blows while it lasts."
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

    @Test func avatarSelfBuffSummary() throws {
        let summaries = EffectSummaryBuilder.build(for: [
            ActiveEffect(id: 1, effect: .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), remainingTurns: 1),
        ])
        try #expect(summaries.first?.keyword == .holy)
        try #expect(summaries.first?.text == "Avatar: deal 6 Holy damage and gain 4 Block each turn, 1 turn left.")
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

    @Test func multipleDistinctEffectsSharingSameKeywordAllAppear() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .marked(2, 4), remainingTurns: 4),
            ActiveEffect(id: 3, effect: .nextStrikeCritical, remainingTurns: 0),
            ActiveEffect(id: 4, effect: .nextStrikeDouble, remainingTurns: 0),
            ActiveEffect(id: 5, effect: .damageReductionPercent(0.25, 2), remainingTurns: 2),
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 5)
        try #expect(summaries.contains { $0.text.contains("Thorns: 3") })
        try #expect(summaries.contains { $0.text.contains("Marked: takes +2 damage") })
        try #expect(summaries.contains { $0.text.contains("Critical Focus") })
        try #expect(summaries.contains { $0.text.contains("Double Strike") })
        try #expect(summaries.contains { $0.text.contains("Weakened: outgoing damage reduced by 25%") })
    }

    @Test func timedDebuffsAndFlagEffectsProduceFormattedSummaries() throws {
        let effects = [
            ActiveEffect(id: 1, effect: .nextHolyStrike, remainingTurns: 0),
            ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
            ActiveEffect(id: 3, effect: .freezeNextAttacker, remainingTurns: 0),
            ActiveEffect(id: 4, effect: .damageReductionFlat(3, 2), remainingTurns: 2),
            ActiveEffect(id: 5, effect: .strengthReduction(2, 3), remainingTurns: 3),
            ActiveEffect(id: 6, effect: .maximumManaBonus(2), remainingTurns: 0),
            ActiveEffect(id: 7, effect: .hemorrhage(4), remainingTurns: 0),
        ]
        let summaries = EffectSummaryBuilder.build(for: effects)
        try #expect(summaries.count == 7)
        try #expect(summaries.contains { $0.text.contains("Holy Strike:") })
        try #expect(summaries.contains { $0.text.contains("Evasion:") })
        try #expect(summaries.contains { $0.text.contains("Glacial Ward:") })
        try #expect(summaries.contains { $0.text.contains("Dazzled:") })
        try #expect(summaries.contains { $0.text.contains("Weakened Soul:") })
        try #expect(summaries.contains { $0.text.contains("Maximum Mana: +2.") })
        try #expect(summaries.contains { $0.text.contains("Hemorrhage: 4 Bleed") })
    }

    @Test func borderAuraEffectsAllGenerateActiveEffectSummaries() throws {
        let auraEffects: [(Effect, String)] = [
            (.nextStrikeDouble, "Double Strike"),
            (.evadeNextHit, "Evasion"),
            (.nextStrikeCritical, "Critical Focus"),
            (.freezeNextAttacker, "Glacial Ward"),
            (.onHitDamage(.freeze, 2), "Glacial Ward"),
            (.onHitDamage(.burn, 3), "Burn Ward"),
            (.onHitDamage(.holy, 4), "Holy Ward"),
            (.thorns(2), "Thorns"),
            (.avatar(holyDamage: 6, blockPerTurn: 4, turns: 2), "Avatar"),
            (.marked(2, 4), "Marked"),
            (.recurringDamage(.freeze, 3, 2), "Freeze"),
            (.recurringDamage(.stun, 3, 2), "Stun"),
        ]
        for (effect, expectedKeyword) in auraEffects {
            let summaries = EffectSummaryBuilder.build(for: [
                ActiveEffect(id: 1, effect: effect, remainingTurns: 2),
            ])
            try #expect(!summaries.isEmpty, "Aura effect \(effect) should produce an active effect summary")
            try #expect(summaries.first?.text.contains(expectedKeyword) == true)
        }
    }
}
