import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Everything the branch-choice overlay needs to fan out ghost copies of a
/// played card and commit the player's pick.
struct BranchChoicePresentation: Equatable {
    let cardID: Int
    let owner: BattleParticipant
    let artworkName: String?
    let choices: [AbilityBranchChoice]
    /// Card center inside the field coordinate space at presentation time.
    let sourceCenter: CGPoint
    let cardSize: CGSize
    let rotation: CGFloat
}

extension BattleSession {
    /// True when a manual play of `card` must first ask which outcome branch
    /// to resolve. Auto-battle never presents; it plays through seeded RNG.
    func shouldPresentBranchChoice(for card: BattleCard) -> Bool {
        guard !isAutoBattleEnabled,
              !isDealingOpeningHand,
              spectacle.activeCinematic == nil,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat,
              let engineState,
              engineState.phase == .playerTurn,
              !engineState.isBattleOver,
              engineState.isCardPlayable(card)
        else { return false }
        return engineState.requiresBranchChoice(cardID: card.id)
    }

    func presentBranchChoice(for card: BattleCard, activation request: CardActivationRequest) {
        guard shouldPresentBranchChoice(for: card),
              let choices = card.ability.outcomeChoices
        else { return }
        pendingBranchChoice = BranchChoicePresentation(
            cardID: card.id,
            owner: card.owner,
            artworkName: card.ability.artReference?.imageName,
            choices: choices,
            sourceCenter: request.center,
            cardSize: request.size,
            rotation: request.rotation
        )
    }

    func dismissBranchChoice() {
        guard pendingBranchChoice != nil else { return }
        pendingBranchChoice = nil
        feedback.noteItemsChanged()
    }
}
