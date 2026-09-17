public struct GameIcon: Hashable, Sendable {
    public let symbolName: String

    private init(symbolName: String) {
        self.symbolName = symbolName
    }

    public static func system(_ name: String) -> Self {
        Self(symbolName: name)
    }

    /// Authored content uses `sf:` identifiers; bare SF names resolve identically.
    public init(id: String) {
        if id.hasPrefix("sf:") {
            self = .system(String(id.dropFirst(3)))
        } else {
            self = .system(id)
        }
    }

    public var id: String {
        "sf:\(symbolName)"
    }
}
