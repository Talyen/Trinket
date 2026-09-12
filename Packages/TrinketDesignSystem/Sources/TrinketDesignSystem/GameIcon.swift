public enum GameIcon: Hashable, Sendable {
    case system(String)

    public init(id: String) {
        if id.hasPrefix("lucide:") {
            let name = String(id.dropFirst(7))
            self = .system(Self.legacySymbols[name] ?? name)
        } else if id.hasPrefix("sf:") {
            self = .system(String(id.dropFirst(3)))
        } else {
            self = .system(id)
        }
    }

    public var symbolName: String {
        switch self {
        case let .system(name): name
        }
    }

    public var id: String {
        "sf:\(symbolName)"
    }
}
