import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import UIKit
@testable import TrinketFeatureSupport

struct GameIconCatalogTests {
    @Test func `authored game icons resolve across providers`() throws {
        let talentIDs = GameContent.combatants.flatMap { combatant in
            CombatantTalentCatalog.config(for: combatant.id).trees.flatMap { $0.nodes.compactMap(\.iconID) }
        }
        let encounterIDs = GameContent.chapters.flatMap { $0.stages.map(\.encounter.iconID) }
        let contentIDs = Set(talentIDs + encounterIDs + GameContent.homesteadNodes.map(\.iconID)
            + LabyrinthNodeType.allCases.map(\.iconID))
        var icons = Set(contentIDs.map(GameIcon.init(id:)))
        icons.formUnion(Keyword.allCases.map(\.visualStyle.icon))
        icons.formUnion(HomesteadResource.allCases.map(\.icon))

        for id in contentIDs {
            #expect(id.hasPrefix("lucide:") || id.hasPrefix("sf:"), "Unqualified content icon: \(id)")
        }
        for icon in icons {
            if let resource = icon.imageResource {
                let image = UIImage(resource: resource)
                #expect(image.size.width > 0 && image.size.height > 0, "Missing \(icon.id)")
            } else if case let .system(name) = icon {
                _ = try #require(UIImage(systemName: name), "Missing \(icon.id)")
            }
        }
        #expect(GameIcon(id: "leaf.fill") == .system("leaf.fill"))
    }
}
