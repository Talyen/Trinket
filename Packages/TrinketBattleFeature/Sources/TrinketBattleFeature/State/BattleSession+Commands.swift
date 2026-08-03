import BattleEngine
import Foundation

extension BattleSession {
    /// Plays a card through the per-run command coordinator.
    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now
    ) -> BattleCardPlayResolution {
        commandCoordinator.playCard(cardID: cardID, at: date)
    }

    /// Ends the player turn through the per-run command coordinator.
    @discardableResult
    func endTurn(at date: Date = .now) -> Int? {
        commandCoordinator.endTurn(at: date)
    }

    func driveAutoBattle(
        isCardCastActive: @escaping @MainActor () -> Bool,
        isManualInteractionActive: @escaping @MainActor () -> Bool,
        playCard: @escaping @MainActor (BattleCard) async -> Bool
    ) async {
        await commandCoordinator.driveAutoBattle(
            isAutoBattleEnabled: { [weak self] in self?.isAutoBattleEnabled == true },
            isCardCastActive: isCardCastActive,
            isManualInteractionActive: isManualInteractionActive,
            playCard: playCard
        )
    }
}
