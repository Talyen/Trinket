import TrinketContent
import TrinketCore

public struct BoonChoice: Identifiable, Hashable, Sendable {
    public let boon: BoonDefinition
    public let artworkName: String?

    public var id: String {
        boon.id
    }

    public init(boon: BoonDefinition, artworkName: String?) {
        self.boon = boon
        self.artworkName = artworkName
    }
}

public struct BoonOffer: Identifiable, Hashable, Sendable {
    public let choices: [BoonChoice]

    public var id: String {
        choices.map(\.id).sorted().joined(separator: "-")
    }

    public init(choices: [BoonChoice]) {
        precondition(choices.count == 3)
        self.choices = choices
    }
}

public struct ActiveBoon: Identifiable, Hashable, Sendable {
    public let boon: BoonDefinition

    public var id: String {
        boon.id
    }

    public init(boon: BoonDefinition) {
        self.boon = boon
    }
}

public struct BoonRuntime: Hashable, Sendable {
    public var storedBlockedDamageByActorID: [String: Int] = [:]
    public var primedRepeatKeywords: Set<Keyword> = []
    public var resolvingBoonIDs: Set<String> = []
    public var depth: Int = 0

    public init() {}
}
