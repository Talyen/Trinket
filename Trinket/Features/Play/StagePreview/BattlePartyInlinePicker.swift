import SwiftUI
import TrinketContent
import TrinketDesignSystem

enum BattlePartySlot: String, Identifiable {
    case hero
    case companion

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var role: Combatant.Role {
        switch self {
        case .hero: .hero
        case .companion: .companion
        }
    }

    var controlAccessibilityID: String {
        switch self {
        case .hero: AccessibilityID.Play.battlePartyHeroControl
        case .companion: AccessibilityID.Play.battlePartyCompanionControl
        }
    }
}

/// Compact Hero + Companion selection placed directly above a battle CTA.
struct BattlePartyInlinePicker: View {
    @Environment(AppState.self) private var appState

    let aspect: AspectDefinition?
    let accentColor: Color

    @State private var presentedSlot: BattlePartySlot?

    init(
        aspect: AspectDefinition? = nil,
        accentColor: Color = TrinketDesign.Colors.accent
    ) {
        self.aspect = aspect
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                slotButton(.hero, combatant: appState.roster.activeHero)
                slotButton(.companion, combatant: appState.roster.activeCompanion)
            }

            if let aspect {
                attunementLine(for: aspect)
            }
        }
        .sheet(item: $presentedSlot) { slot in
            BattleCombatantPickerSheet(
                slot: slot,
                combatants: combatants(for: slot),
                selectedID: selectedID(for: slot),
                aspect: aspect,
                accentColor: accentColor,
                onSelect: { combatant in
                    select(combatant, for: slot)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .disabled(appState.battle.activeBattle != nil)
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyInlinePicker)
    }

    private func slotButton(_ slot: BattlePartySlot, combatant: Combatant) -> some View {
        Button {
            presentedSlot = slot
        } label: {
            HStack(spacing: 8) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(width: 38, height: 48)
                    .clipShape(TrinketDesign.cardShape)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .trinketTypography(.badge)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(combatant.name)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketSurface(.secondary)
            .clipShape(TrinketDesign.cardShape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(slot.controlAccessibilityID)
    }

    @ViewBuilder
    private func attunementLine(for aspect: AspectDefinition) -> some View {
        let status = AspectAttunement.evaluate(
            hero: appState.roster.activeHero,
            companion: appState.roster.activeCompanion,
            aspect: aspect
        )

        Text(status.message)
            .trinketTypography(.footnote)
            .foregroundStyle(
                status.isReady
                    ? AnyShapeStyle(.secondary)
                    : AnyShapeStyle(TrinketDesign.Colors.warning)
            )
            .padding(.horizontal, 4)
    }

    private func combatants(for slot: BattlePartySlot) -> [Combatant] {
        switch slot {
        case .hero: appState.roster.heroes
        case .companion: appState.roster.companions
        }
    }

    private func selectedID(for slot: BattlePartySlot) -> String {
        switch slot {
        case .hero: appState.roster.activeHero.id
        case .companion: appState.roster.activeCompanion.id
        }
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        guard isEligible(combatant) else { return }

        var updatedRoster = appState.roster.current
        switch slot {
        case .hero:
            updatedRoster.setActiveHero(combatant)
        case .companion:
            updatedRoster.setActiveCompanion(combatant)
        }
        appState.roster.current = updatedRoster
    }

    private func isEligible(_ combatant: Combatant) -> Bool {
        guard let aspect else { return true }
        return combatant.keywordProfile.contains(aspect.keyword)
    }
}

/// Native medium-height replacement picker for one party slot.
struct BattleCombatantPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let slot: BattlePartySlot
    let combatants: [Combatant]
    let selectedID: String
    let aspect: AspectDefinition?
    let accentColor: Color
    let onSelect: (Combatant) -> Void

    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(combatants) { combatant in
                        optionButton(combatant)
                    }
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
            .accessibilityIdentifier(AccessibilityID.Play.battlePartyPickerSheet(for: slot.title))
            .navigationTitle("Choose \(slot.title)")
            .navigationBarTitleDisplayMode(.inline)
        }

        .accessibilityIdentifier(AccessibilityID.Play.battlePartyPickerSheet(for: slot.title))
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func optionButton(_ combatant: Combatant) -> some View {
        let eligible = isEligible(combatant)
        let selected = combatant.id == selectedID

        return Button {
            guard eligible else { return }
            onSelect(combatant)
            selectionFeedbackTrigger += 1
            dismiss()
        } label: {
            VStack(spacing: 6) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(maxWidth: .infinity)
                    // UIStyleCheck: allow - Compact picker thumbnails use a fixed visual height.
                    .frame(height: 88)
                    .clipShape(TrinketDesign.cardShape)

                Text(combatant.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    // UIStyleCheck: allow - Reserve label space so grid cards stay aligned.
                    .frame(minHeight: 34)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .trinketSurface(.card)
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(
                        selected ? accentColor : Color.clear,
                        lineWidth: selected ? 3 : 0
                    )
            }
            .opacity(eligible ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!eligible)
        .accessibilityIdentifier(
            AccessibilityID.Play.battlePartyOption(for: slot.title, combatantName: combatant.name)
        )
    }

    private func isEligible(_ combatant: Combatant) -> Bool {
        guard let aspect else { return true }
        return combatant.keywordProfile.contains(aspect.keyword)
    }
}

/// Journey's compact, single-sheet party editor.
struct StageBattlePartyPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let accentColor: Color

    @State private var presentedSlot: BattlePartySlot?
    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        NavigationStack {
            Group {
                if let presentedSlot {
                    BattlePartyOptionsGrid(
                        slot: presentedSlot,
                        combatants: combatants(for: presentedSlot),
                        selectedID: selectedID(for: presentedSlot),
                        accentColor: accentColor,
                        onSelect: { combatant in
                            select(combatant, for: presentedSlot)
                            self.presentedSlot = nil
                        }
                    )
                } else {
                    partySlots
                }
            }
            .navigationTitle(presentedSlot == nil ? "Party" : "Choose \(presentedSlot?.title ?? "")")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.stagePartyPickerSheet)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private var partySlots: some View {
        ScrollView {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                    partySlot(.hero, combatant: appState.roster.activeHero)
                    partySlot(.companion, combatant: appState.roster.activeCompanion)
                }
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: TrinketDesign.Metrics.mediumSpacing) {
                    partySlot(.hero, combatant: appState.roster.activeHero)
                    partySlot(.companion, combatant: appState.roster.activeCompanion)
                }
            }
        }
        .padding(TrinketDesign.Metrics.contentMargin)
    }

    private func partySlot(_ slot: BattlePartySlot, combatant: Combatant) -> some View {
        Button {
            presentedSlot = slot
        } label: {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    ZStack(alignment: .bottomLeading) {
                        CombatantArtwork(combatant: combatant, variant: .card)

                        TrinketHeroScrim.gradient(for: .detailHeader)

                        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                            Text(slot.title)
                                .trinketTypography(.badge)
                                .trinketOnArtText(.eyebrow)
                            Text(combatant.name)
                                .trinketTypography(.cardTitle)
                                .trinketOnArtText(.title)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        .padding(TrinketDesign.Metrics.mediumSpacing)
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()
        }
        .buttonStyle(ArtworkNavigationCardButtonStyle())
        .accessibilityIdentifier(slot.controlAccessibilityID)
        .accessibilityLabel("\(slot.title), \(combatant.name)")
        .accessibilityHint("Choose a different \(slot.title.lowercased())")
    }

    private func combatants(for slot: BattlePartySlot) -> [Combatant] {
        slot == .hero ? appState.roster.heroes : appState.roster.companions
    }

    private func selectedID(for slot: BattlePartySlot) -> String {
        slot == .hero ? appState.roster.activeHero.id : appState.roster.activeCompanion.id
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        var roster = appState.roster.current
        switch slot {
        case .hero:
            roster.setActiveHero(combatant)
        case .companion:
            roster.setActiveCompanion(combatant)
        }
        appState.roster.current = roster
        selectionFeedbackTrigger += 1
    }
}

private struct BattlePartyOptionsGrid: View {
    let slot: BattlePartySlot
    let combatants: [Combatant]
    let selectedID: String
    let accentColor: Color
    let onSelect: (Combatant) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Metrics.partyPickerGridItems,
                spacing: TrinketDesign.Metrics.largeSpacing
            ) {
                ForEach(combatants) { combatant in
                    let selected = combatant.id == selectedID

                    Button {
                        onSelect(combatant)
                    } label: {
                        TrinketDesign.cardShape
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .overlay {
                                ZStack(alignment: .bottomLeading) {
                                    CombatantArtwork(combatant: combatant, variant: .card)

                                    TrinketHeroScrim.gradient(for: .detailHeader)

                                    Text(combatant.name)
                                        .trinketTypography(.cardTitle)
                                        .trinketOnArtText(.title)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.75)
                                        .padding(TrinketDesign.Metrics.mediumSpacing)

                                    if selected {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(accentColor)
                                                    .trinketGlassChip(.compact)
                                                    .accessibilityHidden(true)
                                            }
                                            Spacer()
                                        }
                                        .padding(TrinketDesign.Metrics.smallSpacing)
                                    }
                                }
                            }
                            .clipShape(TrinketDesign.cardShape)
                            .trinketCardSurface()
                            .overlay {
                                TrinketDesign.cardShape.strokeBorder(
                                    selected ? accentColor : .clear,
                                    lineWidth: selected ? 3 : 0
                                )
                            }
                    }
                    .buttonStyle(ArtworkNavigationCardButtonStyle())
                    .accessibilityIdentifier(
                        AccessibilityID.Play.battlePartyOption(for: slot.title, combatantName: combatant.name)
                    )
                    .accessibilityValue(selected ? "Selected" : "Available")
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
    }
}
