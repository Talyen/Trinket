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
