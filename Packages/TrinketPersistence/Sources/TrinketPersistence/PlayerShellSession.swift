import Foundation
import SwiftData

@Model
public final class PlayerShellSession {
    public var id: String = "current"
    public var selectedTabRaw: String = "play"
    public var updatedAt: Date = Date()

    public init(id: String = "current") {
        self.id = id
    }
}
