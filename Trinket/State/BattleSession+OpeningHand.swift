import BattleEngine
import Foundation
import SwiftUI
import TrinketDesignSystem

extension BattleSession {
    func cancelOpeningHandDeal() {
        pendingOpeningHandDealTask?.cancel()
        pendingOpeningHandDealTask = nil
        if isDealingOpeningHand {
            isDealingOpeningHand = false
        }
    }

    /// Opens the battle with an empty hand, then draws each opening card through
    /// the engine so deal-insert transitions can run. Stagger `<= 0` fills the
    /// hand synchronously for unit tests.
    func beginOpeningHandDeal(for configurationID: UUID) {
        guard var battleState = state,
              battleState.hand.count == 0,
              let activeID = activeBattle?.id,
              activeID == configurationID
        else { return }

        if openingHandDrawStagger <= 0 {
            battleState.drawOpeningHand(rebuildLog: false)
            state = battleState
            presentation.install(
                BattlePresentationSnapshot(configurationID: configurationID, state: battleState)
            )
            playSFX(SFXID.abilityDraw)
            return
        }

        isDealingOpeningHand = true
        pendingOpeningHandDealTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isDealingOpeningHand = false
                self.pendingOpeningHandDealTask = nil
            }

            // Opening-hand SFX / first draw must not share the activate frame with
            // shell remount and BattleView construction.
            await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
            guard !Task.isCancelled else { return }
            guard activeBattle?.id == configurationID else { return }

            playSFX(SFXID.abilityDraw)

            while true {
                guard !Task.isCancelled else { return }
                guard activeBattle?.id == configurationID,
                      var battleState = state
                else { return }

                let drew = withAnimation(TrinketMotion.Battle.deal) {
                    let didDraw = battleState.drawNextOpeningHandCard(rebuildLog: false)
                    if didDraw {
                        self.state = battleState
                        self.presentation.install(
                            BattlePresentationSnapshot(
                                configurationID: configurationID,
                                state: battleState
                            )
                        )
                    }
                    return didDraw
                }
                guard drew else { break }

                let stagger = openingHandDrawStagger
                if stagger > 0 {
                    try? await Task.sleep(for: .seconds(stagger))
                }
            }

            guard !Task.isCancelled else { return }
            guard activeBattle?.id == configurationID,
                  var battleState = state
            else { return }

            battleState.finalizeOpeningHand()
            state = battleState
            presentation.install(
                BattlePresentationSnapshot(configurationID: configurationID, state: battleState)
            )
            scheduleAutoEndIfNeeded()
        }
    }

    static func makeBattleState(from configuration: ActiveBattleConfiguration) -> BattleState {
        BattleState(
            hero: configuration.hero.combatant,
            companion: configuration.companion.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            companionModifiers: configuration.companion.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed,
            tracksLog: false,
            dealOpeningHand: false
        )
    }
}
