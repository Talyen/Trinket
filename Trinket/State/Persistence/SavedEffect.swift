import Foundation

enum SavedEffect: Codable, Equatable {
    case damageOverTime(keyword: String, tickDamage: Int, duration: Int)
    case prevention(keyword: String, duration: Int)
    case shield(keyword: String, blockAmount: Int, duration: Int)
    case mitigation(keyword: String, percent: Double, duration: Int)
    case instantHeal(keyword: String, amount: Int)
    case leech(keyword: String, percent: Double, duration: Int)
    case resourceGain(keyword: String, amount: Int)
    case cleanse(keyword: String?, duration: Int)

    init(_ effect: Effect) {
        switch effect {
        case let .damageOverTime(keyword, tickDamage, duration):
            self = .damageOverTime(keyword: keyword.rawValue, tickDamage: tickDamage, duration: duration)
        case let .prevention(keyword, duration):
            self = .prevention(keyword: keyword.rawValue, duration: duration)
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
        }
    }

    func effect() -> Effect? {
        switch self {
        case let .damageOverTime(keywordRawValue, tickDamage, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .damageOverTime(keyword, tickDamage, duration)
        case let .prevention(keywordRawValue, duration):
            guard let keyword = Keyword(rawValue: keywordRawValue) else { return nil }
            return .prevention(keyword, duration)
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
        }
    }
}
