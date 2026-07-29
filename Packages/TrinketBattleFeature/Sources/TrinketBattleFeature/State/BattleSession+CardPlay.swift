import Foundation
import TrinketFeatureSupport

extension BattleSession {
    /// Plays a card from hand. A typed result keeps a successful non-victory play
    /// distinct from rejection while carrying claimed-stage victory gold.
    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now
    ) -> BattleCardPlayResolution {
        cancelPendingAutoEnd()
        feedback.pruneExpired(at: date, notifyPresentation: false)
        pruneExpiredSkillCallout(at: date)
        pruneSoftHold(at: date)
        guard spectacle.activeCinematic == nil,
              !spectacle.isShowingVictory,
              !spectacle.isShowingDefeat,
              !isDealingOpeningHand,
              let battleState = state,
              !battleState.isBattleOver else {
            // No new events — still publish if prune dropped expired chips.
            feedback.noteItemsChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine
            ) {
                try BattleSimBridge.playCard(cardID: cardID, state: &state)
            }
            guard let battleState = state,
                  let configurationID = activeBattle?.id else { return .rejected }

            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardProjection
            ) {
                presentation.install(
                    BattlePresentationSnapshot(configurationID: configurationID, state: battleState)
                )
            }
            measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardFeedback
            ) {
                presentResolvedEvents(events, at: date)
            }
            let earnedGold = handleOutcomeIfNeeded(at: date)
            if earnedGold == nil {
                scheduleAutoEndIfNeeded()
            }
            return .committed(earnedGold: earnedGold)
        } catch {
            #if DEBUG
            BattleFramePacingSignposts.event(
                BattleFramePacingSignposts.Name.playCardRejected,
                detail: "card=\(cardID) error=\(error)"
            )
            #endif
            feedback.noteItemsChanged()
            presentationEnvironment.playSFX([SFXID.uiDeny])
            return .rejected
        }
    }

    private func measurePlayCardInterval<Result>(
        _ name: StaticString,
        operation: () throws -> Result
    ) rethrows -> Result {
        #if DEBUG
        let interval = BattleFramePacingSignposts.signposter.beginInterval(name)
        defer { BattleFramePacingSignposts.signposter.endInterval(name, interval) }
        #endif
        return try operation()
    }
}
