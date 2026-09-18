import SwiftUI

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
        assert(!id.isEmpty, "GameIcon.init(id:) received an empty identifier")
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

public struct GameIconImage: View {
    private let icon: GameIcon
    private let renderingMode: SymbolRenderingMode

    public init(_ icon: GameIcon, renderingMode: SymbolRenderingMode = .monochrome) {
        self.icon = icon
        self.renderingMode = renderingMode
    }

    public var body: some View {
        Image(systemName: icon.symbolName)
            .symbolRenderingMode(renderingMode)
            .accessibilityHidden(true)
    }
}
