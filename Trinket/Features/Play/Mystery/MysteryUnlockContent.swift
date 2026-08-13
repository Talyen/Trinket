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
            subtitle: ceremony.subtitleText,
            subtitleAccessibilityIdentifier: AccessibilityID.Mystery.unlockSubtitle,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
            subtitleColor: ceremony.isSealed
                ? TrinketDesign.Colors.accent
                : .secondary,
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
                    .overlay(alignment: .bottom) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(TrinketDesign.Colors.accent)
                            .opacity(ceremony.checkOpacity)
                            .scaleEffect(ceremony.checkOpacity > 0 ? 1 : 0.85)
                            .offset(y: TrinketDesign.Metrics.largeSpacing)
                            .accessibilityHidden(true)
                    }

                    mysteryPersistFailureBanner(session.persistFailureMessage, centered: true)
                }
            },
            primaryActionTitle: "Recruit",
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: !ceremony.isOffered,
            onPrimaryAction: confirmRecruit,
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5,
            primaryActionOpacity: ceremony.recruitOpacity
        )
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
            .overlay {
                TrinketDesign.cardShape.strokeBorder(
                    TrinketDesign.Colors.accent.opacity(ceremony.ringOpacity),
                    lineWidth: 2
                )
                .scaleEffect(ceremony.ringScale)
                .allowsHitTesting(false)
            }
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
    private(set) var isSealed = false
    private(set) var ringOpacity = 0.0
    private(set) var ringScale = TrinketMotion.Mystery.ringStartScale
    private(set) var checkOpacity = 0.0
    private(set) var unmaskFeedbackTrigger = 0

    private var hasStarted = false
    private var task: Task<Void, Never>?
    private var pendingSealComplete: (() -> Void)?

    var isOffered: Bool {
        phase == .offered
    }

    var allowsDetail: Bool {
        phase == .offered
    }

    var subtitleText: String {
        isSealed ? "RECRUITED" : "UNLOCKED"
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
        if reduceMotion {
            withAnimation(TrinketMotion.Content.fade) {
                isSealed = true
                checkOpacity = 1
                recruitOpacity = 0
                ringOpacity = 0
                ringScale = 1
            }
            finishSeal()
            return
        }

        task = Task { @MainActor in
            let clock = SuspendingClock()
            withAnimation(TrinketMotion.Mystery.seal) {
                recruitOpacity = 0
                isSealed = true
                checkOpacity = 1
                ringOpacity = 1
                ringScale = TrinketMotion.Mystery.ringOvershootScale
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.sealResponse))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Mystery.seal) {
                ringScale = 1
                ringOpacity = 0
            }
            try? await clock.sleep(for: .seconds(TrinketMotion.Mystery.sealHoldBeforeDismiss))
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
