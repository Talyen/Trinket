import CoreText
import SwiftUI

public struct GameIconImage: View {
    @Environment(\.font) private var font
    @Environment(\.fontResolutionContext) private var fontResolutionContext

    private let icon: GameIcon

    public init(_ icon: GameIcon) {
        self.icon = icon
    }

    public var body: some View {
        if let resource = icon.imageResource {
            let resolved = (font ?? .body).resolve(in: fontResolutionContext)
            let size = resolved.pointSize
            let baseline = (size + CTFontGetCapHeight(resolved.ctFont)) / 2

            Image(resource)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .alignmentGuide(.firstTextBaseline) { _ in baseline }
                .alignmentGuide(.lastTextBaseline) { _ in baseline }
                .accessibilityHidden(true)
        } else if case let .system(name) = icon {
            Image(systemName: name)
                .accessibilityHidden(true)
        }
    }
}
