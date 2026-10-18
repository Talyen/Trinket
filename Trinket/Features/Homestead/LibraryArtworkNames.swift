import TrinketAppState
import TrinketContent

enum LibraryArtworkNames {
    static func forRoute(_ route: HomesteadRoute) -> [String] {
        switch route {
        case .bestiary:
            GameContent.enemies.prefix(2).compactMap { $0.combatant.artReference?.thumbnailImageName }
        case .research:
            EquipmentRecipe.archery.filter { $0.researchID != nil }.compactMap { $0.forgeArtwork?.thumbnailImageName }
        case let .researchProject(id):
            project(id)
        case let .researchRecipe(id):
            EquipmentRecipe.matching(id)?.forgeArtwork.map { [$0.imageName] } ?? []
        default: []
        }
    }

    private static func project(_ id: String) -> [String] {
        guard let project = ResearchProject.matching(id) else { return [] }
        var names = project.recipeID.flatMap(EquipmentRecipe.matching)?.forgeArtwork?.thumbnailImageName.map { [$0] } ?? []
        for objective in project.objectives {
            if case let .defeat(id) = objective, let name = GameContent.enemy(matching: id)?.combatant.artReference?.thumbnailImageName {
                names.append(name)
            }
        }
        return names
    }
}
