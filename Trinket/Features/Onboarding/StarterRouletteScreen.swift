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

struct StarterRouletteScreen: View {
    @Environment(OptionsStore.self) private var options

    let role: Combatant.Role
    let combatants: [Combatant]
    let screenAccessibilityID: String
    let onConfirm: (String) -> Bool

    @State private var scrollEntryID: String?
    @State private var selectionFeedbackTrigger = 0
    @State private var inspectedCombatant: Combatant?
    @State private var persistError: String?
    @State private var saveErrorTrigger = 0

    init(
        role: Combatant.Role,
        combatants: [Combatant],
        screenAccessibilityID: String,
        initialSelectionID: String? = nil,
        onConfirm: @escaping (String) -> Bool,
    ) {
        self.role = role
        self.combatants = combatants
        self.screenAccessibilityID = screenAccessibilityID
        self.onConfirm = onConfirm
        let initialID = initialSelectionID.flatMap { id in combatants.contains(where: { $0.id == id }) ? id : nil }
        _scrollEntryID = State(initialValue: initialID ?? combatants.first?.id)
    }

    private var selectedCombatant: Combatant? {
        combatants.first(where: { $0.id == scrollEntryID })
    }

    var body: some View {
        ZStack {
            activeBackgroundEffect
                .ignoresSafeArea()

            GeometryReader { geometry in
                let layout = RouletteLayout(containerSize: geometry.size)

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)

                    Spacer(minLength: TrinketDesign.Spacing.small)

                    if combatants.isEmpty {
                        ContentUnavailableView(
                            "No \(role.rawValue) Choices",
                            systemImage: "person.fill.questionmark",
                            description: Text("Starter choices are unavailable right now. Try relaunching."),
                        )
                        .frame(height: layout.bandHeight)
                    } else {
                        wheelBand(layout: layout)

                        pageIndicator
                    }

                    namePlate
                        .padding(.top, TrinketDesign.Spacing.small)
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)

                    continueAction
                        .padding(.top, TrinketDesign.Spacing.medium)
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)

                    Spacer(minLength: TrinketDesign.Layout.sectionSpacing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .trinketScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(screenAccessibilityID)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .error,
            trigger: saveErrorTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: scrollEntryID) { _, _ in
            selectionFeedbackTrigger += 1
        }
        .trinketFailureAlert("Couldn't Save Progress", message: $persistError)
        .sheet(item: $inspectedCombatant) { combatant in
            NavigationStack {
                CombatantDetailPane(snapshot: CombatantCardDetail(combatant: combatant))
                    .accessibilityIdentifier(
                        AccessibilityID.Onboarding.detail(combatantID: combatant.id),
                    )
            }
            .trinketDetailSheet()
        }
    }

    private var header: some View {
        Text("CHOOSE A \(role.rawValue.uppercased())")
            .trinketTypography(.eyebrow)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, TrinketDesign.Layout.sectionSpacing)
    }

    private var activeBackgroundEffect: some View {
        KeywordPlasmaBackground(
            keywords: selectedCombatant?.affinityKeywords ?? [],
            isMotionActive: inspectedCombatant == nil,
        )
    }

    private func wheelBand(layout: RouletteLayout) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: TrinketDesign.Spacing.medium) {
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

        return InspectableTapButton(
            action: {
                if isCentered {
                    inspectedCombatant = combatant
                } else {
                    center(on: combatant)
                }
            },
            longPress: {
                inspectedCombatant = combatant
            },
            label: {
                CombatantCard(
                    combatant: combatant,
                    showsName: false,
                    isSelected: isCentered,
                )
                .shineBorder(
                    Shine.keywords(combatant.affinityKeywords),
                    cornerRadius: TrinketDesign.Corners.card,
                    lineWidth: 2,
                    isMotionActive: isCentered,
                )
                .frame(width: layout.cardWidth, height: layout.cardHeight)
            },
        )
        .trinketSelectionCardButtonStyle()
        .scrollTransition(.interactive, axis: .horizontal) { content, transitionPhase in
            let distance = min(abs(transitionPhase.value), 1)
            return content
                .scaleEffect(1 - distance * RouletteLayout.edgeScaleDrop)
                .opacity(1 - distance * RouletteLayout.edgeDimming)
        }
        .accessibilityIdentifier(
            AccessibilityID.Onboarding.option(role: role, combatantID: combatant.id),
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            ForEach(combatants) { combatant in
                let isSelected = selectedCombatant?.id == combatant.id
                Circle()
                    .fill(isSelected ? TrinketDesign.Colors.accent : Color.secondary.opacity(0.35))
                    .frame(width: isSelected ? 7 : 5, height: isSelected ? 7 : 5)
            }
        }
        .accessibilityHidden(true)
        .animation(TrinketMotion.Interaction.selection, value: selectedCombatant?.id)
        .padding(.top, TrinketDesign.Spacing.small)
    }

    private var namePlate: some View {
        VStack(spacing: TrinketDesign.Spacing.extraSmall) {
            if let selectedCombatant {
                Text(balanced: selectedCombatant.name)
                    .trinketTypography(.screenTitle)
                    .trinketFittedText()
                    .contentTransition(.numericText())

                let affinities = selectedCombatant.affinityKeywords
                if !affinities.isEmpty {
                    HStack(spacing: TrinketDesign.Spacing.small) {
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

    private var continueAction: some View {
        Button("Continue", action: confirm)
            .disabled(selectedCombatant == nil)
            .trinketPrimaryActionButton(
                accessibilityIdentifier: AccessibilityID.Onboarding.confirm(role: role),
            )
            .trinketCenteredPrimaryAction()
    }

    private func center(on combatant: Combatant) {
        guard scrollEntryID != combatant.id else { return }
        withAnimation(StarterRouletteMotion.plateSwap) {
            scrollEntryID = combatant.id
        }
    }

    private func confirm() {
        guard let selectedCombatant else { return }
        if !onConfirm(selectedCombatant.id) {
            saveErrorTrigger += 1
            persistError = "Your choice was not saved. Please try again."
        }
    }
}

private struct RouletteLayout {
    static let edgeScaleDrop: CGFloat = 0.08
    static let edgeDimming: CGFloat = 0.45

    let containerSize: CGSize

    var cardWidth: CGFloat {
        min(containerSize.width * 0.58, 250)
    }

    var cardHeight: CGFloat {
        min(cardWidth * 4.0 / 3.0, max(0, containerSize.height * 0.45))
    }

    var bandHeight: CGFloat {
        cardHeight + TrinketDesign.Spacing.large
    }

    var edgeMargin: CGFloat {
        max(0, (containerSize.width - cardWidth) / 2)
    }
}
