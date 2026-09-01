import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct LabyrinthCampfireView: View {
    private enum Phase: Equatable {
        case idle
        case resting
        case done
    }

    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(OptionsStore.self) private var options
    @Environment(\.playSFX) private var playSFX
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthNodeSession

    @State private var phase: Phase = .idle
    @State private var barHealthByCombatantID: [String: Int] = [:]
    @State private var counterHealthByCombatantID: [String: Int] = [:]
    @State private var artAppeared = false
    @State private var contentAppeared = false
    @State private var healHapticTrigger = 0

    private static let counterDuration = Duration.milliseconds(900)
    private static let barAnimation = Animation.easeOut(duration: 1.25)
    private static let continueDelay = Duration.milliseconds(400)

    var body: some View {
        EncounterReadingShell(
            artVisible: artAppeared,
            copyVisible: contentAppeared,
            artwork: { campfireArtwork },
            copy: { campfireCopy },
            content: { campfireContent },
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthCampfire)
        .interactiveDismissDisabled(phase == .resting)
        .trinketSensoryFeedback(
            .success,
            trigger: healHapticTrigger,
            enabled: options.hapticsEnabled,
        )
        .onAppear {
            EncounterReadingEntrance.present(
                artAppeared: $artAppeared,
                copyAppeared: $contentAppeared,
            )
        }
    }

    private var campfireArtwork: some View {
        Group {
            if let artID = LabyrinthMapPresentation.destinationEncounterArtID(for: .rest),
               let art = ArtCatalog.encounterArtByID[artID] {
                Image.preparedAsset(art, displaySize: .full)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()
            } else {
                ZStack {
                    TrinketDesign.Colors.encounterRest.opacity(0.16)
                    Image(systemName: "flame.fill")
                        .trinketTypography(.sectionDisplay)
                        .foregroundStyle(TrinketDesign.Colors.encounterRest)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .trinketCardSurface()
        .frame(maxWidth: .infinity)
    }

    private var campfireCopy: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            Text("Campfire")
                .trinketTypography(.screenTitle)
            Text("A fire crackles against the dark.")
                .trinketTypography(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var campfireContent: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
            Text("Rest to restore 30% of each ally's Health.")
                .trinketTypography(.badge)
                .foregroundStyle(.secondary)

            ForEach(session.party) { member in
                partyMeter(member)
            }

            if let failureMessage = session.failureMessage {
                Text(failureMessage)
                    .trinketTypography(.badge)
                    .foregroundStyle(TrinketDesign.Colors.warning)
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthCampfireFailure)
                    .transition(.opacity)
            }

            primaryAction
                .trinketCenteredPrimaryAction()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(TrinketMotion.Interaction.stateChange, value: phase)
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch phase {
        case .idle:
            Button(action: beginRest) {
                Text("Rest")
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton(tint: TrinketDesign.Colors.success)
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthCampfireRest)

        case .resting, .done:
            Text("The party presses on…")
                .trinketTypography(.button)
                .foregroundStyle(TrinketDesign.Colors.success)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TrinketDesign.Spacing.medium)
                .contentTransition(.opacity)
        }
    }

    private func partyMeter(_ member: CampfirePartyMember) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(member.name)
                    .trinketTypography(.cardTitle)
                Spacer()
                counterText(member)
            }

            healthBar(member)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(member.name): \(displayedCounter(member)) of \(member.maxHealth) Health",
        )
    }

    private func counterText(_ member: CampfirePartyMember) -> some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            Text(displayedCounter(member))
                .monospacedDigit()
            Text("/ \(member.maxHealth)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .trinketTypography(.statValue)
    }

    private func displayedCounter(_ member: CampfirePartyMember) -> String {
        let value = switch phase {
        case .idle:
            member.currentHealth
        case .resting, .done:
            counterHealthByCombatantID[member.combatantID] ?? member.currentHealth
        }
        return "\(value)"
    }

    private func healthBar(_ member: CampfirePartyMember) -> some View {
        GeometryReader { geometry in
            let fraction = healthFraction(for: member)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(TrinketDesign.Colors.battleHealth)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: TrinketDesign.Bars.statHeight)
        .animation(Self.barAnimation, value: barHealthByCombatantID[member.combatantID])
    }

    private func healthFraction(for member: CampfirePartyMember) -> CGFloat {
        let displayed = phase == .idle
            ? member.currentHealth
            : (barHealthByCombatantID[member.combatantID] ?? member.currentHealth)
        guard member.maxHealth > 0 else { return 0 }
        return CGFloat(max(0, min(member.maxHealth, displayed))) / CGFloat(member.maxHealth)
    }

    private func beginRest() {
        guard phase == .idle else { return }
        phase = .resting
        playSFX(SFXID.heal, options.effectsVolume)

        for member in session.party where member.healedHealth > member.currentHealth {
            barHealthByCombatantID[member.combatantID] = member.healedHealth
        }
        runEasedCounters()
    }

    private func runEasedCounters() {
        Task { @MainActor in
            let step = Duration.milliseconds(16)
            var elapsed = Duration.zero
            while elapsed < Self.counterDuration {
                try? await Task.sleep(for: step)
                elapsed += step
                let t = min(1.0, elapsed / Self.counterDuration)
                let eased = 1 - pow(1 - t, 3)
                for member in session.party {
                    counterHealthByCombatantID[member.combatantID] = Int(
                        (Double(member.currentHealth)
                            + Double(member.healedHealth - member.currentHealth) * eased
                        ).rounded(),
                    )
                }
            }
            for member in session.party {
                counterHealthByCombatantID[member.combatantID] = member.healedHealth
            }
            await finishRest()
        }
    }

    private func finishRest() async {
        phase = .done
        healHapticTrigger += 1
        try? await Task.sleep(for: Self.continueDelay)
        if labyrinth.finishActiveRest() {
            dismiss()
        } else {
            barHealthByCombatantID = [:]
            counterHealthByCombatantID = [:]
            phase = .idle
        }
    }
}
