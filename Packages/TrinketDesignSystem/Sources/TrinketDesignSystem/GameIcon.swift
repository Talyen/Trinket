import DeveloperToolsSupport
import Foundation

public enum GameIcon: Hashable, Sendable {
    case lucide(String)
    case system(String)

    public init(id: String) {
        if id.hasPrefix("lucide:") {
            self = .lucide(String(id.dropFirst(7)))
        } else if id.hasPrefix("sf:") {
            self = .system(String(id.dropFirst(3)))
        } else {
            self = .system(id)
        }
    }

    public var id: String {
        switch self {
        case let .lucide(name): "lucide:\(name)"
        case let .system(name): "sf:\(name)"
        }
    }

    public var imageResource: ImageResource? {
        guard case let .lucide(name) = self else { return nil }
        return ImageResource(name: "lucide-\(name)", bundle: .module)
    }
}
