import Foundation
import TrinketCore

public extension GameContent {
    static var nodeModifiers: [NodeModifierDefinition] {
        NodeModifierCatalog.modifiers
    }

    static func nodeModifier(id: NodeModifierID) -> NodeModifierDefinition? {
        NodeModifierCatalog.modifier(id: id)
    }
}
