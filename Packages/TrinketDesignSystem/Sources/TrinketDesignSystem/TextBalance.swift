import SwiftUI

public extension String {
    /// Returns a copy of the string with the space before the final word replaced with a non-breaking space (`\u{00A0}`),
    /// binding the final words together to prevent single-word orphan line wraps.
    func trinketBalanced() -> String {
        guard let lastNonWhitespace = lastIndex(where: { !$0.isWhitespace }) else {
            return self
        }
        let prefix = self[...lastNonWhitespace]
        guard let lastWordStart = prefix.lastIndex(where: { $0.isWhitespace }) else {
            return self
        }
        var result = self
        result.replaceSubrange(lastWordStart ... lastWordStart, with: "\u{00A0}")
        return result
    }
}

public extension Text {
    /// Creates a `Text` view with text-balancing applied to bind trailing words and eliminate single-word orphan line wraps.
    init(balanced text: String) {
        self.init(text.trinketBalanced())
    }

    /// Returns a `Text` view constructed from the balanced string representation of `text`.
    static func trinketBalanced(_ text: String) -> Text {
        Text(text.trinketBalanced())
    }
}
