import SwiftUI

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
