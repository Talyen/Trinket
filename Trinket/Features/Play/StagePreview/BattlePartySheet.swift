import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Pre-battle party pick: Hero + Pet carousels and a Start CTA.
struct BattlePartySheet: View {
    @Environment(AppState.self) private var appState

    let title: String
    var subtitle: String?
    var aspect: AspectDefinition?
    var accentColor: Color?
    let onStart: () -> Void

    @State private var selectedHeroID: String
    @State private var selectedPetID: String
    @State private var heroScrollTarget: String?
    @State private var petScrollTarget: String?
    @State private var startFeedbackTrigger = 0
    @State private var didScrollToSelection = false

    init(
        title: String,
        subtitle: String? = nil,
        aspect: AspectDefinition? = nil,
        accentColor: Color? = nil,
        initialHero: Combatant,
        initialPet: Combatant,
        onStart: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.aspect = aspect
        self.accentColor = accentColor
        self.onStart = onStart

        let heroID = Self.eligibleID(for: initialHero, aspect: aspect) ?? ""
        let petID = Self.eligibleID(for: initialPet, aspect: aspect) ?? ""
        _selectedHeroID = State(initialValue: heroID)
        _selectedPetID = State(initialValue: petID)
        _heroScrollTarget = State(initialValue: heroID.isEmpty ? initialHero.id : heroID)
        _petScrollTarget = State(initialValue: petID.isEmpty ? initialPet.id : petID)
    }

    private var heroes: [Combatant] {
        appState.roster.heroes
    }

    private var pets: [Combatant] {
        appState.roster.pets
    }

    private var selectedHero: Combatant? {
        guard !selectedHeroID.isEmpty else { return nil }
        return heroes.first { $0.id == selectedHeroID }
    }

    private var selectedPet: Combatant? {
        guard !selectedPetID.isEmpty else { return nil }
        return pets.first { $0.id == selectedPetID }
    }

    private var canStart: Bool {
        guard !selectedHeroID.isEmpty, !selectedPetID.isEmpty else { return false }
        guard appState.battle.activeBattle == nil else { return false }
        guard let aspect else { return true }
        guard let hero = selectedHero, let pet = selectedPet else { return false }
        return AspectAttunement.evaluate(hero: hero, pet: pet, aspect: aspect).isReady
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                    header
                    partyShelf(title: "Heroes", combatants: heroes, role: .hero)
                    partyShelf(title: "Pets", combatants: pets, role: .pet)
                }
                .padding(.top, TrinketDesign.Metrics.mediumSpacing)
                .padding(.bottom, TrinketDesign.Metrics.largeSpacing)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    startFeedbackTrigger += 1
                    onStart()
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(accentColor ?? .accentColor)
                .disabled(!canStart)
                .accessibilityIdentifier(AccessibilityID.Play.battlePartyStart)
                .trinketSensoryFeedback(
                    .selection,
                    trigger: startFeedbackTrigger,
                    enabled: appState.options.hapticsEnabled
                )
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketScreenBackground(.modal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard !didScrollToSelection else { return }
                didScrollToSelection = true
                if !selectedHeroID.isEmpty {
                    heroScrollTarget = selectedHeroID
                } else {
                    heroScrollTarget = heroes.first(where: isEligible)?.id
                }
                if !selectedPetID.isEmpty {
                    petScrollTarget = selectedPetID
                } else {
                    petScrollTarget = pets.first(where: isEligible)?.id
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.battlePartySheet)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let aspect {
                attunementLine(for: aspect)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
    }

    @ViewBuilder
    private func attunementLine(for aspect: AspectDefinition) -> some View {
        let status: AspectAttunement = {
            guard let hero = selectedHero, let pet = selectedPet else {
                if selectedHeroID.isEmpty {
                    return .missingHeroAffinity
                }
                return .missingPetAffinity
            }
            return AspectAttunement.evaluate(hero: hero, pet: pet, aspect: aspect)
        }()

        Text(status.message)
            .font(.footnote)
            .foregroundStyle(status.isReady ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            .padding(.top, 4)
    }

    private func partyShelf(title: String, combatants: [Combatant], role: Combatant.Role) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            Text(title)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: TrinketDesign.Metrics.collectionShelfCardSpacing) {
                    ForEach(combatants) { combatant in
                        partyCard(combatant, role: role)
                            .id(combatant.id)
                            .collectionShelfCardWidth()
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, TrinketDesign.Metrics.shelfVerticalPadding)
            }
            .contentMargins(
                .horizontal,
                TrinketDesign.Metrics.collectionShelfHorizontalMargin,
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: role == .hero ? $heroScrollTarget : $petScrollTarget)
        }
    }

    private func partyCard(_ combatant: Combatant, role: Combatant.Role) -> some View {
        let isEligible = isEligible(combatant)
        let isSelected = selectedID(for: role) == combatant.id

        return Button {
            select(combatant, role: role)
        } label: {
            BattlePartyCombatantCard(
                combatant: combatant,
                isSelected: isSelected,
                isDimmed: !isEligible
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEligible)
        .accessibilityIdentifier("\(combatant.name) party option")
        .accessibilityValue(isSelected ? "Selected" : (isEligible ? "Available" : "Not attuned"))
    }

    private func isEligible(_ combatant: Combatant) -> Bool {
        Self.isEligible(combatant, aspect: aspect)
    }

    private func selectedID(for role: Combatant.Role) -> String? {
        switch role {
        case .hero: return selectedHeroID.isEmpty ? nil : selectedHeroID
        case .pet: return selectedPetID.isEmpty ? nil : selectedPetID
        case .enemy: return nil
        }
    }

    private func select(_ combatant: Combatant, role: Combatant.Role) {
        guard isEligible(combatant) else { return }

        var updatedRoster = appState.roster.current
        switch role {
        case .hero:
            selectedHeroID = combatant.id
            heroScrollTarget = combatant.id
            updatedRoster.setActiveHero(combatant)
        case .pet:
            selectedPetID = combatant.id
            petScrollTarget = combatant.id
            updatedRoster.setActivePet(combatant)
        case .enemy:
            return
        }
        appState.roster.current = updatedRoster
    }

    private static func isEligible(_ combatant: Combatant, aspect: AspectDefinition?) -> Bool {
        guard let aspect else { return true }
        return combatant.keywordProfile.contains(aspect.keyword)
    }

    private static func eligibleID(for combatant: Combatant, aspect: AspectDefinition?) -> String? {
        isEligible(combatant, aspect: aspect) ? combatant.id : nil
    }
}

private struct BattlePartyCombatantCard: View {
    let combatant: Combatant
    let isSelected: Bool
    let isDimmed: Bool

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .fill(Color(.secondarySystemBackground))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                }
                .overlay {
                    TrinketDesign.cardShape
                        .strokeBorder(
                            isSelected ? TrinketDesign.Colors.selection : Color.clear,
                            lineWidth: 3
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, TrinketDesign.Colors.selection)
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                .trinketCardSurface()

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isDimmed ? .tertiary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .trinketCardLabelSpace()
        }
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name) card")
    }
}
