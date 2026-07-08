import Foundation
import TrinketContent

enum AccessibilityID {
    enum Screen {
        static let play = "Play Screen"
        static let homestead = "Homestead Screen"
    }

    enum Play {
        static func chapterHeader(number: Int) -> String {
            "Chapter \(number) Header"
        }
    }

    enum CombatantDetail {
        static let statsSection = "Combatant Stats Section"
        static let healthStat = "Combatant Health Stat"
        static let traitSection = "Combatant Trait Section"
        static let traitDescription = "Combatant Trait Description"
        static let enemyTraitsSection = "Combatant Enemy Traits Section"
        static let enemyTraitDescription = "Combatant Enemy Trait Description"
    }

    enum Collection {
        static let inventoryEmptyState = "Inventory Empty State"
        static let inventoryNoResults = "Inventory No Results"
        static let inventoryCategory = "Inventory collection category"
    }

    enum Search {
        static let emptyState = "Search Empty State"
        static let noResults = "Search No Results"
    }

    enum Homestead {
        static func node(title: String) -> String {
            "\(title) Homestead Node"
        }

        static func nodeDetail(title: String) -> String {
            "\(title) Homestead Detail"
        }
    }

    enum Battle {
        /// Present when a combatant pane is showing the Skill charge wipe.
        static func skillCharge(combatantName: String) -> String {
            "\(combatantName) skill charge"
        }
    }
}
