import Foundation

public struct ActiveEffect: Identifiable, Hashable, Sendable {
    public let id: Int
    public var effect: Effect
    public var remainingTurns: Int
    public var sourceActorID: String?

    public init(id: Int, effect: Effect, remainingTurns: Int, sourceActorID: String? = nil) {
        self.id = id
        self.effect = effect
        self.remainingTurns = remainingTurns
        self.sourceActorID = sourceActorID
    }

    public var keyword: Keyword {
        effect.keyword
    }

    public var isAwaitingActionSkip: Bool {
        effect.isActionSkipPending && remainingTurns == 0
    }
}

public struct EffectSummary: Identifiable, Equatable, Hashable, Sendable {
    public let keyword: Keyword
    public let text: String

    public init(keyword: Keyword, text: String) {
        self.keyword = keyword
        self.text = text
    }

    /// Display-only identity for row diffing; not stable across text edits and
    /// never a persistence key. Consumed by BattleEngine effect handlers and
    /// TrinketFeatureSupport detail views.
    public var id: String {
        "\(keyword.rawValue):\(text)"
    }
}
