import TrinketContent
import TrinketCore
import TrinketPersistence

struct HomesteadScreenState {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    func projectStatus(for definition: HomesteadNodeDefinition) -> HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }

    func balance(for resource: HomesteadResource) -> Int {
        homestead.balance(for: resource, roster: roster)
    }
}
