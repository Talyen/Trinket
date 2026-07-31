import Foundation

/// A user-facing message emitted when a map action cannot be completed.
///
/// The message is intentionally kept in the persistence-free support module so
/// feature views can present failures without depending on map or save adapters.
public struct StageMapMessage: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
