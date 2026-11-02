public extension AccessibilityID.Homestead {
    static func activity(_ id: String) -> String {
        "Homestead Activity \(id)"
    }

    static let transmute = "Crucible Transmute"
    static let inscribe = "Runesmith Inscribe"
    static let wish = "Well Wish"
    static let clearWish = "Well Clear Wish"

    static func inscriptionItem(_ id: String) -> String {
        "Inscription Item \(id)"
    }

    static func inscriptionAffix(_ id: String) -> String {
        "Inscription Affix \(id)"
    }

    static func wishItem(_ id: String) -> String {
        "Wish Item \(id)"
    }
}
