import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

/// First-launch starter picker: a native paged carousel that rolls to a random
/// suggestion, then hands browsing and confirmation to the player.
struct StarterRouletteScreen: View {
    private enum Phase {
        case rolling
        case landed
    }

    private struct WheelEntry: Identifiable, Equatable {
        let lap: Int
        let combatant: Combatant

        var id: String {
            "\(lap)#\(combatant.id)"
        }
    }

    /// Roster repeats so the opening roll travels a few card widths.
    private static let rollLaps = 3

    @Environment(OptionsStore.self) private var options
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let roleName: String
    let combatants: [Combatant]
    let screenAccessibilityID: String
    let onConfirm: (String) -> Bool

    @State private var scrollEntryID: String?
    @State private var selectedCombatant: Combatant?
    @State private var phase: Phase = .rolling
    @State private var landingFeedbackTrigger = 0
    @State private var selectionFeedbackTrigger = 0
    @State private var inspectedCombatant: Combatant?
    @State private var showsSaveFailure = false
    @State private var isConfirming = false

    init(
        roleName: String,
        combatants: [Combatant],
        screenAccessibilityID: String,
        onConfirm: @escaping (String) -> Bool
    ) {
        self.roleName = roleName
        self.combatants = combatants
        self.screenAccessibilityID = screenAccessibilityID
        self.onConfirm = onConfirm
        // The wheel opens resting on the first entry with its name already up;
        // the roll then travels from there instead of flashing an empty plate.
        _scrollEntryID = State(
            initialValue: combatants.first.map { WheelEntry(lap: 0, combatant: $0).id }
        )
        _selectedCombatant = State(initialValue: combatants.first)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = RouletteLayout(screenWidth: geometry.size.width)

            VStack(spacing: 0) {
                header

                Spacer(minLength: TrinketDesign.Metrics.sectionSpacing)

                wheelBand(layout: layout)

                namePlate
                    .padding(.top, TrinketDesign.Metrics.mediumSpacing)

                Spacer(minLength: TrinketDesign.Metrics.sectionSpacing)

                confirmAction
                    .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .trinketScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(screenAccessibilityID)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        .trinketSensoryFeedback(
            .success,
            trigger: landingFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        // A re-revealed screen (edge-swipe past the hidden nav bar) must not
        // stay locked out of Confirm by a stale in-flight flag.
        .onAppear { isConfirming = false }
        .task { await runCeremony() }
        .onChange(of: scrollEntryID) { _, newID in
            guard let newID,
                  let entry = entries.first(where: { $0.id == newID })
            else { return }
            updateSelection(entry.combatant)
        }
        .alert("Couldn't Save Progress", isPresented: $showsSaveFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your choice was not saved. Please try again.")
        }
        .sheet(item: $inspectedCombatant) { combatant in
            NavigationStack {
                CombatantDetailPane(snapshot: CombatantCardDetail(combatant: combatant))
                    .accessibilityIdentifier(
                        AccessibilityID.Onboarding.detail(combatantID: combatant.id)
                    )
            }
            .trinketDetailSheet()
        }
    }

    // MARK: Header

    private var header: some View {
        Text("CHOOSE A \(roleName.uppercased())")
            .trinketTypography(.eyebrow)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, TrinketDesign.Metrics.sectionSpacing)
    }

    // MARK: Wheel

    private var entries: [WheelEntry] {
        (0 ..< Self.rollLaps).flatMap { lap in
            combatants.map { WheelEntry(lap: lap, combatant: $0) }
        }
    }

    private func wheelBand(layout: RouletteLayout) -> some View {
        // Eager stack: every entry must exist so `scrollPosition(id:)` can land
        // on the last-lap winner; a lazy container never materializes that cell
        // and the programmatic roll silently no-ops.
        ScrollView(.horizontal) {
            HStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                ForEach(entries) { entry in
                    wheelCard(entry, layout: layout)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollEntryID)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        // Blocks touch input mid-roll without disabling scrolling itself —
        // `scrollDisabled` also rejects the programmatic roll, leaving the
        // wheel stuck at its starting layout while the binding moves on.
        .allowsHitTesting(phase == .landed)
        .contentMargins(.horizontal, layout.edgeMargin, for: .scrollContent)
        .frame(height: layout.bandHeight)
    }

    private func wheelCard(_ entry: WheelEntry, layout: RouletteLayout) -> some View {
        let isCentered = selectedCombatant?.id == entry.combatant.id

        return InspectableTapButton(
            action: { center(on: entry) },
            longPress: { inspectedCombatant = entry.combatant },
            label: {
                CombatantCard(
                    combatant: entry.combatant,
                    showsName: false,
                    isSelected: isCentered
                )
                .frame(width: layout.cardWidth, height: layout.cardHeight)
            }
        )
        .trinketSelectionCardButtonStyle()
        // First-party carousel emphasis: cards shrink and dim as they leave the
        // viewport center. Continuous with `.interactive`; no per-frame
        // geometry transforms to fight the scroll layout.
        .scrollTransition(.interactive, axis: .horizontal) { content, transitionPhase in
            let distance = min(abs(transitionPhase.value), 1)
            return content
                .scaleEffect(1 - distance * RouletteLayout.edgeScaleDrop)
                .opacity(1 - distance * RouletteLayout.edgeDimming)
        }
        // One flat AX node per card keeps the snapshot small and stable
        // across the carousel's continuous transitions.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            AccessibilityID.Onboarding.option(role: roleName, combatantID: entry.combatant.id)
        )
        .accessibilityValue(isCentered ? "Selected" : "Not selected")
    }

    // MARK: Name plate

    private var namePlate: some View {
        Group {
            if let selectedCombatant {
                Text(balanced: selectedCombatant.name)
                    .trinketTypography(.screenTitle)
                    .id(selectedCombatant.id)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(TrinketMotion.Onboarding.plateSwap, value: selectedCombatant?.id)
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // MARK: Confirm action

    private var confirmAction: some View {
        Button("Confirm", action: confirm)
            .disabled(selectedCombatant == nil || isConfirming)
            .trinketPrimaryActionButton()
            .trinketCenteredPrimaryAction()
            .accessibilityLabel(confirmAccessibilityLabel)
            .accessibilityIdentifier(AccessibilityID.Onboarding.confirm(role: roleName))
            .accessibilityAddTraits(.isButton)
    }

    private var confirmAccessibilityLabel: String {
        guard let selectedCombatant else { return "Confirm \(roleName)" }
        return "Confirm \(selectedCombatant.name)"
    }

    // MARK: Ceremony

    private func runCeremony() async {
        guard phase == .rolling, let winner = drawWinner() else { return }
        let target = WheelEntry(lap: Self.rollLaps - 1, combatant: winner)

        if reduceMotion || AppEnvironment.shared.skipOnboardingCeremony {
            scrollEntryID = target.id
            settle(on: winner, target: target)
            return
        }

        try? await Task.sleep(for: .seconds(TrinketMotion.Onboarding.rollStartDelay))
        guard !Task.isCancelled else { return }

        withAnimation(TrinketMotion.Onboarding.roll) {
            scrollEntryID = target.id
        }

        try? await Task.sleep(for: .seconds(TrinketMotion.Onboarding.rollDuration))
        guard !Task.isCancelled else { return }

        settle(on: winner, target: target)
    }

    /// Landing pins the resting position and selection explicitly — a dropped
    /// scroll echo mid-roll must never desync the name plate or lock Confirm.
    private func settle(on winner: Combatant, target: WheelEntry) {
        if scrollEntryID != target.id {
            scrollEntryID = target.id
        }
        updateSelection(winner)
        phase = .landed
        landingFeedbackTrigger += 1
    }

    private func drawWinner() -> Combatant? {
        guard !combatants.isEmpty else { return nil }
        let index: Int
        if let seed = AppEnvironment.shared.starterRouletteSeed {
            var rng = SeededRandomNumberGenerator(seed: UInt64(bitPattern: Int64(seed)))
            index = Int.random(in: 0 ..< combatants.count, using: &rng)
        } else {
            var rng = SystemRandomNumberGenerator()
            index = Int.random(in: 0 ..< combatants.count, using: &rng)
        }
        return combatants[index]
    }

    // MARK: Interaction

    private func updateSelection(_ combatant: Combatant) {
        guard selectedCombatant?.id != combatant.id else { return }
        withAnimation(TrinketMotion.Onboarding.plateSwap) {
            selectedCombatant = combatant
        }
        // Skip the buzz while names churn during the roll.
        if phase == .landed {
            selectionFeedbackTrigger += 1
        }
    }

    private func center(on entry: WheelEntry) {
        guard phase == .landed, scrollEntryID != entry.id else { return }
        withAnimation(TrinketMotion.Onboarding.plateSwap) {
            scrollEntryID = entry.id
        }
    }

    private func confirm() {
        guard let selectedCombatant, !isConfirming else { return }
        isConfirming = true
        if !onConfirm(selectedCombatant.id) {
            isConfirming = false
            showsSaveFailure = true
        }
    }
}

// MARK: Layout metrics

private struct RouletteLayout {
    static let edgeScaleDrop: CGFloat = 0.08
    static let edgeDimming: CGFloat = 0.45

    let screenWidth: CGFloat

    var cardWidth: CGFloat {
        min(screenWidth * 0.58, 290)
    }

    var cardHeight: CGFloat {
        cardWidth * 1.42
    }

    var bandHeight: CGFloat {
        cardHeight + TrinketDesign.Metrics.largeSpacing
    }

    /// Leading/trailing inset that centers exactly one card in the viewport.
    var edgeMargin: CGFloat {
        max(0, (screenWidth - cardWidth) / 2)
    }
}
