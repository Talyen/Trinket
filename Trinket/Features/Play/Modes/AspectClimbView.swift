import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectClimbView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var partyPicker: PartyPickerKind?
    @State private var floorMessage: StageMapMessage?
    @State private var scrollTarget: String?

    let aspectID: AspectID

    private var aspect: AspectDefinition? {
        GameContent.aspect(id: aspectID)
    }

    private var floors: [AspectFloor] {
        GameContent.aspectFloors(for: aspectID)
    }

    private var progress: PlayerAspectsState {
        appState.aspects.current
    }

    private var attunement: AspectAttunement {
        guard let aspect else { return .missingHeroAffinity }
        return AspectAttunement.evaluate(
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            aspect: aspect
        )
    }

    private var activeFloorNumber: Int {
        guard let aspect else { return 1 }
        return progress.activeFloor(for: aspectID.rawValue, floorCount: aspect.floorCount)
    }

    private var showsItemAffinityHint: Bool {
        guard let aspect else { return false }
        let heroItems = equippedKeywords(for: appState.roster.activeHero)
        let petItems = equippedKeywords(for: appState.roster.activePet)
        return !heroItems.contains(aspect.keyword) && !petItems.contains(aspect.keyword)
    }

    var body: some View {
        Group {
            if let aspect {
                climbContent(aspect)
            } else {
                ContentUnavailableView("Aspect Missing", systemImage: "sparkles")
            }
        }
        .navigationTitle(aspect?.title ?? "Aspect")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.playJourney)
        .accessibilityIdentifier(AccessibilityID.Play.aspectClimb(aspectID.rawValue))
        .sheet(item: $partyPicker) { picker in
            PartyPickerSheet(
                kind: picker,
                combatants: combatants(for: picker),
                onSelect: { combatant in
                    select(combatant, for: picker)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $floorMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: activeFloorNumber)?.id
        }
        .onChange(of: activeFloorNumber) { _, newValue in
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: newValue)?.id
        }
    }

    @ViewBuilder
    private func climbContent(_ aspect: AspectDefinition) -> some View {
        let style = aspect.keyword.visualStyle
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(aspect.epithet, systemImage: style.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.color)
                    Text(attunement.message)
                        .font(.footnote)
                        .foregroundStyle(attunement.isReady ? .secondary : .orange)
                    if showsItemAffinityHint {
                        Text("Affinity gear helps — not required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                ActivePartyPickerRow(
                    hero: appState.roster.activeHero,
                    pet: appState.roster.activePet,
                    onHeroPicker: { partyPicker = .hero },
                    onPetPicker: { partyPicker = .pet }
                )

                LazyVStack(spacing: 12) {
                    ForEach(floors) { floor in
                        floorCard(floor, aspect: aspect, style: style)
                            .id(floor.id)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, 16)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .animation(reduceMotion ? nil : .smooth, value: scrollTarget)
    }

    @ViewBuilder
    private func floorCard(
        _ floor: AspectFloor,
        aspect: AspectDefinition,
        style: Keyword.VisualStyle
    ) -> some View {
        let startable = progress.isFloorStartable(floor.floor, aspectID: aspect.id.rawValue)
        let cleared = progress.isFloorCleared(floor.floor, aspectID: aspect.id.rawValue)
        let unlocked = progress.isFloorUnlocked(
            floor.floor,
            aspectID: aspect.id.rawValue,
            floorCount: aspect.floorCount
        )
        let isActive = startable

        VStack(alignment: .leading, spacing: isActive || !cleared ? 12 : 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(floor.isWarden ? "Warden · Floor \(floor.floor)" : "Floor \(floor.floor)")
                        .font(isActive ? .title3.weight(.bold) : .headline)
                    if unlocked || cleared, let enemy = GameContent.enemy(matching: floor.enemyID) {
                        Text(enemy.combatant.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if cleared {
                        Text("Cleared")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Cleared")
                } else if !startable {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Locked")
                }
            }

            if startable {
                Button {
                    beginFloor(floor)
                } label: {
                    Text("Begin Floor")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(style.color)
                .disabled(!attunement.isReady || appState.battle.activeBattle != nil)
            }
        }
        .padding(isActive ? 16 : 14)
        .trinketSurface(isActive ? .elevated : (cleared || unlocked ? .elevated : .denseRow))
        .opacity(startable || cleared ? 1 : 0.7)
        .accessibilityIdentifier(AccessibilityID.Play.aspectFloor(aspect.id.rawValue, floor: floor.floor))
        .animation(reduceMotion ? nil : .smooth, value: startable)
    }

    private func beginFloor(_ floor: AspectFloor) {
        if let message = appState.startAspectBattle(for: floor) {
            floorMessage = message
        }
    }

    private func combatants(for picker: PartyPickerKind) -> [Combatant] {
        switch picker {
        case .hero:
            return appState.roster.heroes
        case .pet:
            return appState.roster.pets
        }
    }

    private func select(_ combatant: Combatant, for picker: PartyPickerKind) {
        var updatedRoster = appState.roster.current
        switch picker {
        case .hero:
            updatedRoster.setActiveHero(combatant)
        case .pet:
            updatedRoster.setActivePet(combatant)
        }
        appState.roster.current = updatedRoster
    }

    private func equippedKeywords(for combatant: Combatant) -> Set<Keyword> {
        let loadout = appState.roster.equipmentLoadout(for: combatant)
        var keywords = Set<Keyword>()
        for slot in combatant.role.equipmentSlots {
            guard let itemID = loadout.itemID(for: slot),
                  let item = appState.inventory.item(matching: itemID)
            else { continue }
            keywords.formUnion(item.baseType.keywordAffinities)
        }
        return keywords
    }
}
