import Foundation

struct ActiveEffect: Identifiable, Hashable {
    let id: Int
    var effect: Effect
    var remainingTicks: Int
    var sourceActorID: String?

    init(id: Int, effect: Effect, remainingTicks: Int, sourceActorID: String? = nil) {
        self.id = id
        self.effect = effect
        self.remainingTicks = remainingTicks
        self.sourceActorID = sourceActorID
    }

    var keyword: Keyword {
        effect.keyword
    }

    var summary: String {
        EffectPresentation.activePhrase(for: self)
    }
}

struct EffectSummary: Identifiable, Equatable, Hashable {
    let keyword: Keyword
    let text: String

    var id: Keyword {
        keyword
    }
}
