import Foundation
import SwiftUI
import TrinketBattleRuntime
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

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
        guard runtime.simulation.hasState,
              runtime.simulation.hand.isEmpty,
              let activeID = activeBattle?.id,
              activeID == configurationID
        else { return }

        if openingHandDrawStagger <= 0 {
            _ = runtime.simulation.drawOpeningHand()
            installSimulationPresentation()
            presentationEnvironment.playSFX([SFXID.abilityDraw])
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

            presentationEnvironment.playSFX([SFXID.abilityDraw])

            while true {
                guard !Task.isCancelled else { return }
                guard activeBattle?.id == configurationID,
                      runtime.simulation.hasState
                else { return }

                let drew = withAnimation(TrinketMotion.Battle.deal) {
                    let didDraw = runtime.simulation.drawNextOpeningHandCard()
                    if didDraw {
                        self.installSimulationPresentation()
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
                  runtime.simulation.hasState
            else { return }

            runtime.simulation.finalizeOpeningHand()
            installSimulationPresentation()
            scheduleAutoEndIfNeeded()
        }
    }
}
