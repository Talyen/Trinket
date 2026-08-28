import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryUnlockContent: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.playSFX) private var playSFX
    @Bindable var session: MysteryEncounterSession
    let unlockedID: String
    let onSelectDetail: (CombatantDetailContext) -> Void
    let onFinish: () -> Bool
    let onDismiss: () -> Void

    @State private var ceremony = MysteryRecruitCeremonyState()

    var body: some View {
        Group {
            if let combatant = revealCombatant(id: unlockedID) {
                recruitUnlockStage(combatant: combatant)
                    .trinketSensoryFeedback(
                        .success,
                        trigger: ceremony.unmaskFeedbackTrigger,
                        enabled: options.hapticsEnabled
                    )
                    .trinketSensoryFeedback(
                        .success,
                        trigger: ceremony.sealFeedbackTrigger,
                        enabled: options.hapticsEnabled
                    )
                    .onAppear {
                        ceremony.start {
                            playSFX(SFXID.uiConfirm, options.effectsVolume)
                        }
                    }
            }
        }
        .onDisappear {
            ceremony.cancel()
        }
    }

    private func recruitUnlockStage(combatant: Combatant) -> some View {
        ZStack {
            KeywordPlasmaBackground(keywords: recruitPlasmaKeywords(for: combatant))

            RewardRevealShell(
                eyebrow: combatant.role == .companion ? "New Companion" : "New Hero",
                eyebrowAccessibilityIdentifier: AccessibilityID.Mystery.unlockEyebrow,
                title: combatant.name,
                subtitle: "UNLOCKED",
                subtitleAccessibilityIdentifier: AccessibilityID.Mystery.unlockSubtitle,
                titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
                eyebrowOpacity: ceremony.eyebrowOpacity,
                titleOpacity: ceremony.titleOpacity,
                subtitleOpacity: ceremony.subtitleOpacity,
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
                            recruitPortrait(combatant: combatant)
                        }
                        // UIStyleCheck: allow - Unlock art is the tap target for combatant detail; no button chrome.
                        .trinketQuietTapButtonStyle()
                        .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
                        .scaleEffect(ceremony.artScale)
                        .frame(maxWidth: 430)
                        .allowsHitTesting(ceremony.allowsDetail)
                        .overlay(alignment: .bottomTrailing) {
                            recruitSealBadge
                        }

                        mysteryPersistFailureBanner(session.persistFailureMessage, centered: true)
                    }
                },
                primaryActionTitle: "Recruit",
                primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
                isPrimaryActionDisabled: !ceremony.isOffered,
                onPrimaryAction: confirmRecruit,
                pinsPrimaryActionToBottom: false,
                primaryActionOpacity: ceremony.recruitOpacity
            )
        }
    }

    private func recruitPlasmaKeywords(for combatant: Combatant) -> [Keyword] {
        CombatantTalentCatalog.combatantTreeAffinities[combatant.id]?.map(\.keyword) ?? []
    }

    private var recruitSealBadge: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
            Text("RECRUITED")
                .trinketTypography(.badge)
        }
        .foregroundStyle(TrinketDesign.Colors.canvas)
        .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
        .background(
            Capsule()
                .fill(TrinketDesign.Colors.accent)
        )
        .opacity(ceremony.checkOpacity)
        .scaleEffect(ceremony.sealBadgeScale)
        .offset(
            x: -TrinketDesign.Metrics.mediumSpacing,
            y: -TrinketDesign.Metrics.mediumSpacing
        )
        .accessibilityHidden(ceremony.checkOpacity < 1)
    }

    private func recruitPortrait(combatant: Combatant) -> some View {
        CombatantArtwork(combatant: combatant, variant: .hero)
            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
            .saturation(1 - ceremony.veilAmount)
            .brightness(MysteryCeremonyMotion.veiledBrightness * ceremony.veilAmount)
            .overlay {
                TrinketDesign.Colors.canvas
                    .opacity(MysteryCeremonyMotion.veiledOverlayOpacity * ceremony.veilAmount)
                    .allowsHitTesting(false)
            }
            .overlay {
                RadialGradient(
                    colors: [
                        TrinketDesign.Colors.accent.opacity(ceremony.bloomOpacity),
                        TrinketDesign.Colors.accent.opacity(0),
                    ],
                    center: .center,
                    startRadius: 12,
                    endRadius: 220
                )
                .allowsHitTesting(false)
            }
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
    }

    private func confirmRecruit() {
        guard ceremony.isOffered else { return }
        guard onFinish() else { return }
        ceremony.beginSeal(onComplete: onDismiss)
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
