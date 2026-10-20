public extension AccessibilityID.Homestead {
    static let bestiary = "Library Bestiary"
    static let research = "Library Research"
    static let openBestiary = "Library Open Bestiary"
    static let openResearch = "Library Open Research"
    static let openWorkshop = "Library Open Workshop"
    static let viewResearch = "Library View Research"
    static func bestiaryEnemy(_ id: String) -> String {
        "Bestiary Enemy \(id)"
    }

    static func researchProject(_ id: String) -> String {
        "Research Project \(id)"
    }

    static func researchProjectDetail(_ id: String) -> String {
        "Research Detail \(id)"
    }

    static func researchReward(_ id: String) -> String {
        "Research Reward \(id)"
    }

    static func researchEnemy(_ id: String) -> String {
        "Research Enemy \(id)"
    }
}

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
