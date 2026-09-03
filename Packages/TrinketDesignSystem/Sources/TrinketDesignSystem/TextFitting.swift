import SwiftUI

public extension View {
    func trinketFittedText() -> some View {
        lineLimit(nil)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }

    func trinketSingleLineFittedText(minimumScaleFactor: CGFloat = 0.62) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
            .allowsTightening(true)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
    }
}
