import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryUnlockContent: View {
    @Environment(PlaySession.self) private var play
    @Environment(PlayerSaveStore.self) private var playerSave
    @Bindable var session: MysteryEncounterSession
    let unlockedID: String
    let onSelectDetail: (CombatantDetailContext) -> Void

    @State private var unlockFeedbackTrigger = 0
    @State private var revealSequence = RewardRevealSequenceState()

    private static let chromeStepCount = 4
    private static let eyebrowStep = 1
    private static let titleStep = 2
    private static let subtitleStep = 3
    private static let artStep = 4

    var body: some View {
        Group {
            if let combatant = revealCombatant(id: unlockedID) {
                recruitUnlockStage(combatant: combatant)
                    .trinketSensoryFeedback(
                        .success,
                        trigger: unlockFeedbackTrigger,
                        enabled: play.options.hapticsEnabled
                    )
                    .onAppear {
                        unlockFeedbackTrigger += 1
                        revealSequence.startChromeSteps(Self.chromeStepCount)
                    }
            }
        }
        .onDisappear {
            // Cancel without completion left Recruit locked when @State survived
            // (same class as VictoryView / ExperienceBar onDisappear snap).
            revealSequence.cancelChrome(stepCount: Self.chromeStepCount)
        }
    }

    private func recruitUnlockStage(combatant: Combatant) -> some View {
        let artVisible = revealSequence.visibleChromeStepCount >= Self.artStep

        return RewardRevealShell(
            eyebrow: combatant.role == .companion ? "New Companion" : "New Hero",
            eyebrowAccessibilityIdentifier: AccessibilityID.Mystery.unlockEyebrow,
            title: combatant.name,
            subtitle: "UNLOCKED",
            subtitleAccessibilityIdentifier: AccessibilityID.Mystery.unlockSubtitle,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
            eyebrowOpacity: revealSequence.chromeOpacity(visibleFrom: Self.eyebrowStep),
            titleOpacity: revealSequence.chromeOpacity(visibleFrom: Self.titleStep),
            subtitleOpacity: revealSequence.chromeOpacity(visibleFrom: Self.subtitleStep),
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Button {
                        onSelectDetail(
                            CombatantDetailContext(
                                kind: combatant.role == .companion ? .companion : .hero,
                                combatantID: combatant.id
                            )
                        )
                    } label: {
                        CombatantArtwork(combatant: combatant, variant: .hero)
                            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
                            .clipShape(TrinketDesign.cardShape)
                            .trinketCardSurface()
                    }
                    // UIStyleCheck: allow - Unlock art is the tap target for combatant detail; no button chrome.
                    .trinketQuietTapButtonStyle()
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
                    .opacity(artVisible ? 1 : 0)
                    .scaleEffect(artVisible ? 1 : 0.94)
                    .frame(maxWidth: 430)
                    .allowsHitTesting(artVisible)

                    mysteryPersistFailureBanner(session.persistFailureMessage, centered: true)
                }
            },
            primaryActionTitle: revealSequence.isSequenceComplete ? "Recruit" : nil,
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: false,
            onPrimaryAction: {
                _ = play.encounters.finishActiveMysteryEncounter()
            },
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5
        )
    }

    private func revealCombatant(id: String) -> Combatant? {
        if let sessionCombatant = session.combatant, sessionCombatant.id == id {
            return playerSave.roster.configuredCombatant(sessionCombatant)
        }
        let catalog = GameContent.heroes + GameContent.companions
        guard let combatant = catalog.first(where: { $0.id == id }) else { return nil }
        return playerSave.roster.configuredCombatant(combatant)
    }
}
