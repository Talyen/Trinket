public extension AccessibilityID.Homestead {
    static let craftButton = "Blacksmith Craft Button"
    static let forgeSheet = "Blacksmith Forge Sheet"
    static let forgeAdded = "Blacksmith Added to Inventory"
    static let forgeGrid = "Blacksmith Forge Grid"
    static let forgePreview = "Blacksmith Forge Preview"
    static let forgeButton = "Blacksmith Forge Button"
    static let forgeResult = "Blacksmith Forge Result"
    static let forgeDetail = "Blacksmith Forge Detail"
    static let forgeDone = "Blacksmith Forge Done"

    static func forgeRecipe(_ id: String) -> String {
        "Blacksmith Recipe \(id)"
    }
}
