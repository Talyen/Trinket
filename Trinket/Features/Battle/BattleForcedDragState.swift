import CoreGraphics
import Observation

/// Performance-harness (and lab) forced drag. Fine-grained observation so only the
/// targeted hand card reads `translation` while siblings only watch `cardID`.
@MainActor
@Observable
final class BattleForcedDragState {
    var cardID: Int?
    var translation: CGSize = .zero
    /// Bumped to ask the targeted card to commit through production `beginPlay`
    /// (same path as a finger release above the play threshold).
    private(set) var playCommitGeneration = 0

    func set(cardID: Int, translation: CGSize) {
        if self.cardID != cardID {
            self.cardID = cardID
        }
        self.translation = translation
    }

    func requestPlay() {
        guard cardID != nil else { return }
        playCommitGeneration &+= 1
    }

    func clear() {
        cardID = nil
        translation = .zero
    }
}
