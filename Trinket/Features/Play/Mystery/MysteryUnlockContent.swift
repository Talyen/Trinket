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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        ceremony.start(reduceMotion: reduceMotion) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recruited")
        .accessibilityHidden(ceremony.checkOpacity < 1)
    }

    private func recruitPortrait(combatant: Combatant) -> some View {
        CombatantArtwork(combatant: combatant, variant: .hero)
            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
            .saturation(1 - ceremony.veilAmount)
            .brightness(TrinketMotion.Mystery.veiledBrightness * ceremony.veilAmount)
            .overlay {
                TrinketDesign.Colors.canvas
                    .opacity(TrinketMotion.Mystery.veiledOverlayOpacity * ceremony.veilAmount)
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
        ceremony.beginSeal(reduceMotion: reduceMotion, onComplete: onDismiss)
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

@MainActor
@Observable
final class MysteryRecruitCeremonyState {
    enum Phase: Equatable {
        case veiled
        case unmasking
        case offered
        case sealing
    }

    private(set) var phase: Phase = .veiled
    private(set) var veilAmount = 1.0
    private(set) var bloomOpacity = 0.0
    private(set) var artScale = TrinketMotion.Mystery.veiledArtScale
    private(set) var eyebrowOpacity = 0.0
    private(set) var titleOpacity = 0.0
    private(set) var subtitleOpacity = 0.0
    private(set) var recruitOpacity = 0.0
    private(set) var checkOpacity = 0.0
    private(set) var sealBadgeScale = TrinketMotion.Mystery.sealBadgeStartScale
    private(set) var unmaskFeedbackTrigger = 0
    private(set) var sealFeedbackTrigger = 0

    private var hasStarted = false
    private var task: Task<Void, Never>?
    private var pendingSealComplete: (() -> Void)?

    var isOffered: Bool {
        phase == .offered
    }

    var allowsDetail: Bool {
        phase == .offered
    }

    func start(reduceMotion: Bool, onUnmaskPeak: @escaping () -> Void) {
        guard !hasStarted else { return }
        hasStarted = true
        if reduceMotion {
            withAnimation(TrinketMotion.Content.fade) {
                snapToOfferedVisuals()
            }
            onUnmaskPeak()
            unmaskFeedbackTrigger += 1
            return
        }

        task = Task { @MainActor in
            await runUnmaskSequence(onUnmaskPeak: onUnmaskPeak)
        }
    }

    private func runUnmaskSequence(onUnmaskPeak: @escaping () -> Void) async {
        let clock = SuspendingClock()
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.veilHold))
        guard !Task.isCancelled else { return }

        phase = .unmasking
        withAnimation(TrinketMotion.Mystery.unmask) {
            veilAmount = 0
            artScale = 1
        }
        withAnimation(TrinketMotion.Mystery.bloomIn) {
            bloomOpacity = TrinketMotion.Mystery.bloomPeakOpacity
        }

        try? await clock.sleep(
            for: .seconds(
                TrinketMotion.Mystery.unmaskResponse * TrinketMotion.Mystery.bloomPeakFraction
            )
        )
        guard !Task.isCancelled else { return }
        onUnmaskPeak()
        unmaskFeedbackTrigger += 1
        withAnimation(TrinketMotion.Mystery.bloomOut) {
            bloomOpacity = 0
        }

        try? await clock.sleep(
            for: .seconds(
                TrinketMotion.Mystery.unmaskResponse * (1 - TrinketMotion.Mystery.bloomPeakFraction)
            )
        )
        guard !Task.isCancelled else { return }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeAfterUnmask))
        guard !Task.isCancelled else { return }
        await presentChrome()
        task = nil
    }

    private func presentChrome() async {
        let clock = SuspendingClock()
        withAnimation(TrinketMotion.Mystery.chrome) {
            eyebrowOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            titleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.chromeStagger))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            subtitleOpacity = 1
        }
        try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.recruitButtonDelay))
        guard !Task.isCancelled else { return }
        withAnimation(TrinketMotion.Mystery.chrome) {
            recruitOpacity = 1
        }
        phase = .offered
    }

    func beginSeal(reduceMotion: Bool, onComplete: @escaping () -> Void) {
        guard phase == .offered else { return }
        phase = .sealing
        pendingSealComplete = onComplete
        task?.cancel()
        sealFeedbackTrigger += 1
        if reduceMotion {
            task = Task { @MainActor in
                let clock = SuspendingClock()
                withAnimation(TrinketMotion.Content.fade) {
                    applySealedVisuals()
                }
                try? await clock.sleep(
                    for: .seconds(
                        TrinketMotion.Content.fadeDuration
                            + TrinketMotion.Mystery.sealHoldBeforeDismiss
                    )
                )
                guard !Task.isCancelled else { return }
                finishSeal()
            }
            return
        }

        task = Task { @MainActor in
            let clock = SuspendingClock()
            withAnimation(TrinketMotion.Content.fade) {
                recruitOpacity = 0
                subtitleOpacity = 0
            }
            withAnimation(TrinketMotion.Mystery.seal) {
                checkOpacity = 1
                sealBadgeScale = 1
                artScale = TrinketMotion.Mystery.sealArtPeakScale
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.sealArtPeakDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Mystery.seal) {
                artScale = 1
            }
            try? await clock.sleep(
                for: .seconds(
                    TrinketMotion.Mystery.sealResponse
                        + TrinketMotion.Mystery.sealHoldBeforeDismiss
                        - TrinketMotion.Mystery.sealArtPeakDelay
                )
            )
            guard !Task.isCancelled else { return }
            finishSeal()
        }
    }

    func cancel() {
        let wasSealing = phase == .sealing
        task?.cancel()
        task = nil
        if wasSealing {
            finishSeal()
            return
        }
        if hasStarted {
            snapToOfferedVisuals()
        }
    }

    private func finishSeal() {
        let complete = pendingSealComplete
        pendingSealComplete = nil
        task = nil
        complete?()
    }

    private func applySealedVisuals() {
        recruitOpacity = 0
        subtitleOpacity = 0
        checkOpacity = 1
        sealBadgeScale = 1
    }

    private func snapToOfferedVisuals() {
        veilAmount = 0
        bloomOpacity = 0
        artScale = 1
        eyebrowOpacity = 1
        titleOpacity = 1
        subtitleOpacity = 1
        recruitOpacity = 1
        phase = .offered
    }
}
