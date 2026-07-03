import Foundation

public struct MapScrollRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let targetID: String

    public init(targetID: String, id: UUID = UUID()) {
        self.id = id
        self.targetID = targetID
    }
}
