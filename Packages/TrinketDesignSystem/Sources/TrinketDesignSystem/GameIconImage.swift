import SwiftUI

public struct GameIconImage: View {
    private let icon: GameIcon

    public init(_ icon: GameIcon) {
        self.icon = icon
    }

    public var body: some View {
        Image(systemName: icon.symbolName)
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)
    }
}
