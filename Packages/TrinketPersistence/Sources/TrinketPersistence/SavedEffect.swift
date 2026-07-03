import Foundation
import TrinketCore

public enum SavedEffect: Codable, Equatable, Sendable {
    case burn(potency: Int)
    case poison(potency: Int)
    case bleed(potency: Int)
    case controlMeter(keyword: String, amount: Int, threshold: Int)
    case shield(keyword: String, blockAmount: Int, duration: Int)
    case mitigation(keyword: String, percent: Double, duration: Int)
    case instantHeal(keyword: String, amount: Int)
    case leech(keyword: String, percent: Double, duration: Int)
    case resourceGain(keyword: String, amount: Int)
    case cleanse(keyword: String?)
    case cleanseRandom
    case purge(keyword: String?)
    case purgeRandom
    case halveMitigation(keyword: String)
    case dodge(keyword: String, duration: Int)

    public init(_ effect: Effect) {
        if let saved = SavedEffect.direct(effect) {
            self = saved
            return
        }
        self = SavedEffect.keywordBacked(effect)
    }

    private static func direct(_ effect: Effect) -> SavedEffect? {
        switch effect {
        case let .burn(potency):
            return .burn(potency: potency)
        case let .poison(potency):
            return .poison(potency: potency)
        case let .bleed(potency):
            return .bleed(potency: potency)
        case let .cleanse(keyword):
            return .cleanse(keyword: keyword?.rawValue)
        case .cleanseRandom:
            return .cleanseRandom
        case let .purge(keyword):
            return .purge(keyword: keyword?.rawValue)
        case .purgeRandom:
            return .purgeRandom
        default:
            return nil
        }
    }

    private static func keywordBacked(_ effect: Effect) -> SavedEffect {
        switch effect {
        case let .controlMeter(keyword, amount, threshold):
            return .controlMeter(keyword: keyword.rawValue, amount: amount, threshold: threshold)
        case let .shield(keyword, blockAmount, duration):
            return .shield(keyword: keyword.rawValue, blockAmount: blockAmount, duration: duration)
        case let .mitigation(keyword, percent, duration):
            return .mitigation(keyword: keyword.rawValue, percent: percent, duration: duration)
        case let .instantHeal(keyword, amount):
            return .instantHeal(keyword: keyword.rawValue, amount: amount)
        case let .leech(keyword, percent, duration):
            return .leech(keyword: keyword.rawValue, percent: percent, duration: duration)
        case let .resourceGain(keyword, amount):
            return .resourceGain(keyword: keyword.rawValue, amount: amount)
        case let .halveMitigation(keyword):
            return .halveMitigation(keyword: keyword.rawValue)
        default:
            fatalError("Unhandled effect for persistence: \(effect)")
        }
    }

    public func effect() -> Effect? {
        switch self {
        case let .burn(potency):
            return .burn(potency)
        case let .poison(potency):
            return .poison(potency)
        case let .bleed(potency):
            return .bleed(potency)
        case let .cleanse(keywordRawValue):
            let keyword = keywordRawValue.flatMap(Keyword.init(rawValue:))
            return .cleanse(keyword)
        case .cleanseRandom:
            return .cleanseRandom
        case let .purge(keywordRawValue):
            let keyword = keywordRawValue.flatMap(Keyword.init(rawValue:))
            return .purge(keyword)
        case .purgeRandom:
            return .purgeRandom
        default:
            return keywordBackedEffect()
        }
    }

    private func keywordBackedEffect() -> Effect? {
        switch self {
        case let .controlMeter(keywordRawValue, amount, threshold):
            return keyword(from: keywordRawValue).map { .controlMeter($0, amount, threshold) }
        case let .shield(keywordRawValue, blockAmount, duration):
            return keyword(from: keywordRawValue).map { .shield($0, blockAmount, duration) }
        case let .mitigation(keywordRawValue, percent, duration):
            return keyword(from: keywordRawValue).map { .mitigation($0, percent, duration) }
        case let .instantHeal(keywordRawValue, amount):
            return keyword(from: keywordRawValue).map { .instantHeal($0, amount) }
        case let .leech(keywordRawValue, percent, duration):
            return keyword(from: keywordRawValue).map { .leech($0, percent, duration) }
        case let .resourceGain(keywordRawValue, amount):
            return keyword(from: keywordRawValue).map { .resourceGain($0, amount) }
        case let .halveMitigation(keywordRawValue):
            return keyword(from: keywordRawValue).map { .halveMitigation($0) }
        case .dodge:
            return nil
        default:
            return nil
        }
    }

    private func keyword(from rawValue: String) -> Keyword? {
        Keyword(rawValue: rawValue)
    }
}

public struct SavedActiveEffect: Codable, Equatable {
    public let id: Int
    public let effect: SavedEffect
    public let remainingTicks: Int
    public let sourceActorID: String?

    public init(_ activeEffect: ActiveEffect) {
        id = activeEffect.id
        effect = SavedEffect(activeEffect.effect)
        remainingTicks = activeEffect.remainingTicks
        sourceActorID = activeEffect.sourceActorID
    }

    public func activeEffect() -> ActiveEffect? {
        guard let effect = effect.effect() else { return nil }
        return ActiveEffect(
            id: id,
            effect: effect,
            remainingTicks: remainingTicks,
            sourceActorID: sourceActorID
        )
    }
}
