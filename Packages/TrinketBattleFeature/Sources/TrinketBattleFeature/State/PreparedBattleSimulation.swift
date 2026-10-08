import BattleEngine
import TrinketFeatureContracts

@MainActor
final class PreparedBattleSimulation: PreparedBattleRunHandle {
    let configuration: BattleRunConfiguration
    private(set) var state: BattleState?
    private weak var owner: BattleSession?
    private let generation: Int

    init(configuration: BattleRunConfiguration, state: BattleState, owner: BattleSession, generation: Int) {
        self.configuration = configuration
        self.state = state
        self.owner = owner
        self.generation = generation
    }

    func state(for session: BattleSession) -> BattleState? {
        guard owner === session, generation == session.preparationGeneration else { return nil }
        return state
    }

    func invalidate() {
        state = nil
    }
}
