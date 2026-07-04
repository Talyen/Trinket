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
}
