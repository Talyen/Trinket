import Foundation

enum SavedEffect: Codable, Equatable {
    case burn(potency: Int)
    case poison(potency: Int)
    case bleed(potency: Int)
    case prevention(keyword: String, duration: Int)
    case preventionBuildup(keyword: String, amount: Int, threshold: Int)
    case shield(keyword: String, blockAmount: Int, duration: Int)
    case mitigation(keyword: String, percent: Double, duration: Int)
    case instantHeal(keyword: String, amount: Int)
    case leech(keyword: String, percent: Double, duration: Int)
    case resourceGain(keyword: String, amount: Int)
    case cleanse(keyword: String?, duration: Int)
    case dealDamage(keyword: String, amount: Int)
    case cleanseRandom
    case halveMitigation(keyword: String)
    case dodge(keyword: String, duration: Int)

    init(_ effect: Effect) {
        switch effect {
        case let .burn(potency):
            self = .burn(potency: potency)
        case let .poison(potency):
            self = .poison(potency: potency)
        case let .bleed(potency):
            self = .bleed(potency: potency)
        case let .prevention(keyword, duration):
            self = .prevention(keyword: keyword.rawValue, duration: duration)
        case let .preventionBuildup(keyword, amount, threshold):
            self = .preventionBuildup(keyword: keyword.rawValue, amount: amount, threshold: threshold)
        case let .shield(keyword, blockAmount, duration):
            self = .shield(keyword: keyword.rawValue, blockAmount: blockAmount, duration: duration)
        case let .mitigation(keyword, percent, duration):
            self = .mitigation(keyword: keyword.rawValue, percent: percent, duration: duration)
        case let .instantHeal(keyword, amount):
            self = .instantHeal(keyword: keyword.rawValue, amount: amount)
        case let .leech(keyword, percent, duration):
            self = .leech(keyword: keyword.rawValue, percent: percent, duration: duration)
        case let .resourceGain(keyword, amount):
            self = .resourceGain(keyword: keyword.rawValue, amount: amount)
        case let .cleanse(keyword, duration):
            self = .cleanse(keyword: keyword?.rawValue, duration: duration)
        case let .dealDamage(keyword, amount):
            self = .dealDamage(keyword: keyword.rawValue, amount: amount)
        case .cleanseRandom:
            self = .cleanseRandom
        case let .halveMitigation(keyword):
            self = .halveMitigation(keyword: keyword.rawValue)
        case let .dodge(keyword, duration):
            self = .dodge(keyword: keyword.rawValue, duration: duration)
        }
    }

    func effect() -> Effect? {
        switch self {
        case let .burn(potency):
            return .burn(potency)
        case let .poison(potency):
            return .poison(potency)
        case let .bleed(potency):
            return .bleed(potency)
        case let .prevention(keywordRawValue, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .prevention(keyword, duration)
        case let .preventionBuildup(keywordRawValue, amount, threshold):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .preventionBuildup(keyword, amount, threshold)
        case let .shield(keywordRawValue, blockAmount, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .shield(keyword, blockAmount, duration)
        case let .mitigation(keywordRawValue, percent, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .mitigation(keyword, percent, duration)
        case let .instantHeal(keywordRawValue, amount):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .instantHeal(keyword, amount)
        case let .leech(keywordRawValue, percent, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .leech(keyword, percent, duration)
        case let .resourceGain(keywordRawValue, amount):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .resourceGain(keyword, amount)
        case let .cleanse(keywordRawValue, duration):
            let keyword = keywordRawValue.flatMap { Keyword(rawValue: $0) }
            return .cleanse(keyword, duration)
        case let .dealDamage(keywordRawValue, amount):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .dealDamage(keyword, amount)
        case .cleanseRandom:
            return .cleanseRandom
        case let .halveMitigation(keywordRawValue):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .halveMitigation(keyword)
        case let .dodge(keywordRawValue, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .dodge(keyword, duration)
        }
    }
}

struct SavedActiveEffect: Codable, Equatable {
    let id: Int
    let effect: SavedEffect
    let remainingTicks: Int
    let sourceActorID: String?

    init(_ activeEffect: ActiveEffect) {
        id = activeEffect.id
        effect = SavedEffect(activeEffect.effect)
        remainingTicks = activeEffect.remainingTicks
        sourceActorID = activeEffect.sourceActorID
    }

    func activeEffect() -> ActiveEffect? {
        guard let effect = effect.effect() else { return nil }
        return ActiveEffect(
            id: id,
            effect: effect,
            remainingTicks: remainingTicks,
            sourceActorID: sourceActorID
        )
    }
}
