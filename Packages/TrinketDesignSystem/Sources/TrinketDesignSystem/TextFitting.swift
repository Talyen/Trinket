import SwiftUI

public extension View {
    func trinketFittedText() -> some View {
        lineLimit(nil)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}
