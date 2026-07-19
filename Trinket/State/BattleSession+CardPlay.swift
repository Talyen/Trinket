import Foundation
import TrinketPersistence

extension BattleSession {
    /// Plays a card from hand. A typed result keeps a successful non-victory play
    /// distinct from rejection while carrying claimed-stage victory gold.
    @discardableResult
    func playCard(
        cardID: Int,
        at date: Date = .now,
        journey: JourneyProgressState,
        homestead: PlayerHomesteadState
    ) -> BattleCardPlayResolution {
        cancelPendingAutoEnd()
        pruneExpiredFeedback(at: date, notifyPresentation: false)
        autoEndJourney = journey
        autoEndHomestead = homestead
        guard activeCinematic == nil,
              !isShowingVictory,
              !isShowingDefeat,
              state != nil else {
            // No new events — still publish if prune dropped expired chips.
            noteFeedbackPresentationChanged()
            return .rejected
        }

        do {
            let events = try measurePlayCardInterval(
                BattleFramePacingSignposts.Name.playCardEngine
            ) {
                try state?.playCard(cardID: cardID, rebuildLog: false)
            }
            guard let events, let battleState = state,
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
            let earnedGold = handleOutcomeIfNeeded(at: date, journey: journey, homestead: homestead)
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
            noteFeedbackPresentationChanged()
            playSFX(SFXID.uiDeny)
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
