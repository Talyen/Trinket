import Foundation

/// A user-facing message emitted when a map action cannot be completed.
public struct StageMapMessage: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
