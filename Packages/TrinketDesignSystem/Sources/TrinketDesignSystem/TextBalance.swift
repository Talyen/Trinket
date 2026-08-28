import SwiftUI

public extension String {
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
    init(balanced text: String) {
        self.init(text.trinketBalanced())
    }

    static func trinketBalanced(_ text: String) -> Text {
        Text(text.trinketBalanced())
    }
}
