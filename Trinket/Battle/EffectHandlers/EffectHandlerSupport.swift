import Foundation

enum EffectRemoval {
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) {
        if let keyword {
            effects.removeAll { $0.keyword == keyword && $0.effect.isRemovableDebuff }
        } else {
            effects.removeAll { $0.effect.isRemovableDebuff }
        }
    }

    static func removeRandomDebuff(from effects: inout [ActiveEffect], using rng: inout SeededRandomNumberGenerator) -> Keyword? {
        let debuffs = effects.filter(\.effect.isRemovableDebuff)
        guard let removed = debuffs.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }

    static func removeBuffs(from effects: inout [ActiveEffect], keyword: Keyword?) {
        if let keyword {
            effects.removeAll { $0.keyword == keyword && $0.effect.isRemovableBuff }
        } else {
            effects.removeAll { $0.effect.isRemovableBuff }
        }
    }

    static func removeRandomBuff(from effects: inout [ActiveEffect], using rng: inout SeededRandomNumberGenerator) -> Keyword? {
        let buffs = effects.filter(\.effect.isRemovableBuff)
        guard let removed = buffs.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }
}

enum TimedBuffSummary {
    static func minRemainingTicks(in stacks: [ActiveEffect], duration: (Effect) -> Int?) -> Int {
        stacks.compactMap { active -> Int? in
            guard let baseDuration = duration(active.effect) else { return nil }
            return active.remainingTicks > 0 ? active.remainingTicks : baseDuration
        }.min() ?? 0
    }
}
