import Foundation
import TrinketContent
import TrinketCore

enum EffectRemoval {
    @discardableResult
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableDebuff }
    }

    static func removeDebuffs(from effects: inout [ActiveEffect], keywords: Set<Keyword>) -> [ActiveEffect] {
        let removed = removeMatching(from: &effects, keyword: nil) {
            $0.effect.isRemovableDebuff && keywords.contains($0.keyword)
        }
        // Stable sorting preserves stack order within each reflected keyword.
        return removed.sorted { $0.keyword.rawValue < $1.keyword.rawValue }
    }

    static func removeRandomDebuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
    ) -> ActiveEffect? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableDebuff }
    }

    private static func removeRandom(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
        where matches: (ActiveEffect) -> Bool,
    ) -> ActiveEffect? {
        let count = effects.count(where: matches)
        guard count > 0 else { return nil }
        // Match randomElement's range and stack order without allocating its candidates.
        var offset = Int.random(in: 0 ..< count, using: &rng)
        for index in effects.indices where matches(effects[index]) {
            if offset == 0 {
                return effects.remove(at: index)
            }
            offset -= 1
        }
        return nil
    }

    @discardableResult
    static func removeBuffs(
        from effects: inout [ActiveEffect], keyword: Keyword?, preservingBlock: Bool = false,
    ) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) {
            $0.effect.isRemovableBuff && !(preservingBlock && $0.effect.kind == .shield)
        }
    }

    static func removeBuffs(
        from effects: inout [ActiveEffect],
        count: Int,
        preservingBlock: Bool = false,
        using rng: inout SeededRandomNumberGenerator,
    ) -> [ActiveEffect] {
        guard count > 0 else { return [] }
        if count == 1 {
            let removed = removeRandom(from: &effects, using: &rng) {
                $0.effect.isRemovableBuff && !(preservingBlock && $0.effect.kind == .shield)
            }
            return removed.map { [$0] } ?? []
        }
        var candidates = effects.indices.filter {
            effects[$0].effect.isRemovableBuff && !(preservingBlock && effects[$0].effect.kind == .shield)
        }
        guard !candidates.isEmpty else { return [] }
        var selected = Array(repeating: false, count: effects.count)
        var removed: [ActiveEffect] = []
        for _ in 0 ..< min(count, candidates.count) {
            guard let offset = candidates.indices.randomElement(using: &rng) else { break }
            let index = candidates.remove(at: offset)
            selected[index] = true
            removed.append(effects[index])
        }
        var index = 0
        effects.removeAll { _ in
            defer { index += 1 }
            return selected[index]
        }
        return removed
    }

    @discardableResult
    private static func removeMatching(
        from effects: inout [ActiveEffect],
        keyword: Keyword?,
        where matches: (ActiveEffect) -> Bool,
    ) -> [ActiveEffect] {
        var removed: [ActiveEffect] = []
        effects.removeAll { effect in
            guard matches(effect), keyword == nil || effect.keyword == keyword else { return false }
            removed.append(effect)
            return true
        }
        return removed
    }

    /// Distinct keywords in stable order for per-keyword removal events.
    /// Shared by Cleanse/Purge so the two operations cannot drift apart again.
    static func distinctSortedKeywords(from removed: [ActiveEffect]) -> [Keyword] {
        let distinct = Set(removed.lazy.map(\.keyword))
        return distinct.sorted { $0.rawValue < $1.rawValue }
    }
}

enum TimedBuffSummary {
    static func minRemainingTurns(in stacks: [ActiveEffect], duration: (Effect) -> Int?) -> Int {
        var minimum: Int?
        for active in stacks {
            guard let baseDuration = duration(active.effect) else { continue }
            let turns = active.remainingTurns > 0 ? active.remainingTurns : baseDuration
            minimum = min(minimum ?? turns, turns)
        }
        return minimum ?? 0
    }

    static func durationResource(
        in stacks: [ActiveEffect],
        separator: String = ", ",
        duration: (Effect) -> Int? = { $0.durationTurns },
    ) -> LocalizedStringResource {
        let turns = minRemainingTurns(in: stacks, duration: duration)
        guard turns > 0 else { return L10n.duration_empty }
        let remaining = BattleTiming.remainingDurationResource(turns: turns)
        return separator == "\n" ? L10n.duration_newline(remaining) : L10n.duration_suffix(remaining)
    }

    static func summedAmount(in stacks: [ActiveEffect], amount: (Effect) -> Int?) -> Int {
        stacks.reduce(0) { sum, active in SaturatedArithmetic.saturatingAdd(sum, amount(active.effect) ?? 0) }
    }

    static func maxAmount(in stacks: [ActiveEffect], amount: (Effect) -> Int?) -> Int {
        stacks.reduce(0) { maxAmount, active in max(maxAmount, amount(active.effect) ?? 0) }
    }

    static func maxPercent(in stacks: [ActiveEffect], percent: (Effect) -> Double?) -> Double {
        stacks.reduce(0.0) { maxPercent, active in max(maxPercent, percent(active.effect) ?? 0) }
    }
}

enum ActiveEffectMutation {
    /// Updates existing stacks in order, removing nil results without building another effect array.
    static func update(_ effects: inout [ActiveEffect], _ transform: (ActiveEffect) -> ActiveEffect?) {
        var retainedCount = 0
        for index in effects.indices {
            guard let updated = transform(effects[index]) else { continue }
            effects[retainedCount] = updated
            retainedCount += 1
        }
        effects.removeLast(effects.count - retainedCount)
    }

    static func finishTurn(
        _ active: ActiveEffect,
        replacement: ActiveEffect?,
        on target: Combatant,
        in context: inout BattleState,
    ) {
        context.roster.mutateRuntime(for: target) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: { $0.id == active.id }) else { return }
            if let replacement {
                runtime.activeEffects[index] = replacement
            } else {
                runtime.activeEffects.remove(at: index)
            }
        }
    }

    static func removeMatching(
        from target: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool,
    ) {
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.removeEffects { matches($0.effect) }
        }
    }

    static func reflect(
        _ active: ActiveEffect,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        switch active.effect {
        case let .burn(potency), let .poison(potency), let .bleed(potency):
            await DoTApplicator.applyDoT(
                keyword: active.keyword, potency: potency, to: target, sourceActorID: source.id, application: .reflection,
                durationTurns: active.remainingTurns, in: &context,
            )
            return
        case let .controlMeter(keyword, amount, threshold):
            // Reflect the status itself; recipient resistance still applies to partial buildup.
            await ControlMeterEngine.applyMeterCharge(
                amount, keyword: keyword, to: target, sourceActorID: source.id, applyFightPacing: false,
                preservingTriggeredStatus: threshold > 0 && amount >= threshold, in: &context,
            )
            return
        default:
            context.insertEffect(active.effect, to: target, sourceID: source.id, remainingTurns: active.remainingTurns)
            return
        }
    }
}
