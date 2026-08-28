import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

private enum StarterRouletteMotion {
    static var plateSwap: Animation {
        .spring(response: 0.30, dampingFraction: 0.9)
    }
}

/// First-launch starter picker: a native horizontal carousel that starts on the
/// first combatant and hands browsing and confirmation to the player.
struct StarterRouletteScreen: View {
    @Environment(OptionsStore.self) private var options

    let roleName: String
    let combatants: [Combatant]
    let screenAccessibilityID: String
    let onConfirm: (String) -> Bool

    @State private var scrollEntryID: String?
    @State private var selectedCombatant: Combatant?
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
        _scrollEntryID = State(initialValue: combatants.first?.id)
        _selectedCombatant = State(initialValue: combatants.first)
    }

    var body: some View {
        ZStack {
            activeBackgroundEffect
                .ignoresSafeArea()

            GeometryReader { geometry in
                let layout = RouletteLayout(containerSize: geometry.size)

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                    Spacer(minLength: TrinketDesign.Metrics.smallSpacing)

                    wheelBand(layout: layout)

                    pageIndicator

                    namePlate
                        .padding(.top, TrinketDesign.Metrics.smallSpacing)
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                    continueAction
                        .padding(.top, TrinketDesign.Metrics.mediumSpacing)
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                    Spacer(minLength: TrinketDesign.Metrics.sectionSpacing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .trinketScreenBackground()
        // One AX container for the screen keeps the screen identifier unique
        // instead of flooding every descendant element with it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(screenAccessibilityID)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        // A re-revealed screen (edge-swipe past the hidden nav bar) must not
        // stay locked out of Confirm by a stale in-flight flag.
        .onAppear { isConfirming = false }
        .onChange(of: scrollEntryID) { _, newID in
            guard let newID,
                  let combatant = combatants.first(where: { $0.id == newID })
            else { return }
            updateSelection(combatant)
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

    // MARK: Background Effect View

    private var activeBackgroundEffect: some View {
        KeywordPlasmaBackground(
            keywords: activeKeywords,
            isMotionActive: inspectedCombatant == nil
        )
    }

    // MARK: Wheel

    private func wheelBand(layout: RouletteLayout) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                ForEach(combatants) { combatant in
                    wheelCard(combatant, layout: layout)
                        .id(combatant.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollEntryID)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, layout.edgeMargin, for: .scrollContent)
        .frame(height: layout.bandHeight)
    }

    private func wheelCard(_ combatant: Combatant, layout: RouletteLayout) -> some View {
        let isCentered = selectedCombatant?.id == combatant.id
        let shineKeywords = CombatantTalentCatalog
            .combatantTreeAffinities[combatant.id]?
            .map(\.keyword)

        return Button {
            if isCentered {
                inspectedCombatant = combatant
            } else {
                center(on: combatant)
            }
        } label: {
            CombatantCard(
                combatant: combatant,
                showsName: false,
                isSelected: isCentered
            )
            .keywordShineBorder(
                keywords: shineKeywords,
                cornerRadius: TrinketDesign.Corners.card,
                lineWidth: 2,
                isMotionActive: isCentered
            )
            .frame(width: layout.cardWidth, height: layout.cardHeight)
        }
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
        .accessibilityIdentifier(
            AccessibilityID.Onboarding.option(role: roleName, combatantID: combatant.id)
        )
    }

    // MARK: Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            ForEach(combatants) { combatant in
                let isSelected = selectedCombatant?.id == combatant.id
                Circle()
                    .fill(isSelected ? TrinketDesign.Colors.accent : Color.secondary.opacity(0.35))
                    .frame(width: isSelected ? 7 : 5, height: isSelected ? 7 : 5)
            }
        }
        .accessibilityHidden(true)
        .animation(TrinketMotion.Interaction.selection, value: selectedCombatant?.id)
        .padding(.top, TrinketDesign.Metrics.smallSpacing)
    }

    // MARK: Name plate & Affinities

    private var namePlate: some View {
        VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            if let selectedCombatant {
                Text(balanced: selectedCombatant.name)
                    .trinketTypography(.screenTitle)
                    .contentTransition(.numericText())

                if let affinities = CombatantTalentCatalog.combatantTreeAffinities[selectedCombatant.id]?.map(\.keyword) {
                    HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(affinities, id: \.self) { keyword in
                            Text(keyword.rawValue)
                                .trinketTypography(.cardLabel)
                                .fontWeight(.bold)
                                .foregroundStyle(keyword.visualStyle.color)
                                .contentTransition(.numericText())
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(affinities.map(\.rawValue).joined(separator: ", "))
                }
            }
        }
        .animation(StarterRouletteMotion.plateSwap, value: selectedCombatant?.id)
        .frame(maxWidth: .infinity, minHeight: 68)
    }

    // MARK: Continue action

    private var continueAction: some View {
        Button("Continue", action: confirm)
            .disabled(selectedCombatant == nil || isConfirming)
            .trinketPrimaryActionButton(
                accessibilityIdentifier: AccessibilityID.Onboarding.confirm(role: roleName)
            )
            .trinketCenteredPrimaryAction()
    }

    // MARK: Interaction

    private func updateSelection(_ combatant: Combatant) {
        guard selectedCombatant?.id != combatant.id else { return }
        withAnimation(StarterRouletteMotion.plateSwap) {
            selectedCombatant = combatant
        }
        selectionFeedbackTrigger += 1
    }

    private func center(on combatant: Combatant) {
        guard scrollEntryID != combatant.id else { return }
        withAnimation(StarterRouletteMotion.plateSwap) {
            scrollEntryID = combatant.id
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

    private var activeKeywords: [Keyword] {
        guard let selectedCombatant else { return [] }
        return CombatantTalentCatalog.combatantTreeAffinities[selectedCombatant.id]?.map(\.keyword) ?? []
    }
}

// MARK: Layout metrics

private struct RouletteLayout {
    static let edgeScaleDrop: CGFloat = 0.08
    static let edgeDimming: CGFloat = 0.45

    let containerSize: CGSize

    var cardWidth: CGFloat {
        min(containerSize.width * 0.58, 250)
    }

    var cardHeight: CGFloat {
        cardWidth * 1.42
    }

    var bandHeight: CGFloat {
        cardHeight + TrinketDesign.Metrics.largeSpacing
    }

    /// Leading/trailing inset that centers exactly one card in the viewport.
    var edgeMargin: CGFloat {
        max(0, (containerSize.width - cardWidth) / 2)
    }
}
