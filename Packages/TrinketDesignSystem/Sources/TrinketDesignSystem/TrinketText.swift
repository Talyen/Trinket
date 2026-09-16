import SwiftUI

public extension String {
    func trinketBalanced() -> String {
        guard let lastNonWhitespace = lastIndex(where: { !$0.isWhitespace }) else {
            return self
        }
        let prefix = self[...lastNonWhitespace]
        guard let lastWordStart = prefix.lastIndex(where: { $0 == " " }) else {
            return self
        }
        var result = self
        result.replaceSubrange(lastWordStart ... lastWordStart, with: " ")
        return result
    }
}

public extension Text {
    init(balanced text: String) {
        self.init(text.trinketBalanced())
    }
}

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
