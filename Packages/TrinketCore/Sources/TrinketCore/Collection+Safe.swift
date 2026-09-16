import Foundation

public extension Collection {
    subscript(safe index: Index) -> Element? {
        guard index >= startIndex, index < endIndex else { return nil }
        return self[index]
    }
}
