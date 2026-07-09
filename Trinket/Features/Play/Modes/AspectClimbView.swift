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
        }
    }

    @ViewBuilder
    private func floorCard(
        _ floor: AspectFloor,
        aspect: AspectDefinition,
        style: Keyword.VisualStyle
    ) -> some View {
        let unlocked = progress.isFloorUnlocked(
            floor.floor,
            aspectID: aspect.id.rawValue,
            floorCount: aspect.floorCount
        )
        let cleared = progress.isFloorCleared(floor.floor, aspectID: aspect.id.rawValue)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(floor.isWarden ? "Warden · Floor \(floor.floor)" : "Floor \(floor.floor)")
                        .font(.headline)
                    if let enemy = GameContent.enemy(matching: floor.enemyID) {
                        Text(enemy.combatant.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Cleared")
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Locked")
                }
            }

            if unlocked {
                Button {
                    beginFloor(floor)
                } label: {
                    Text(cleared ? "Replay Floor" : "Begin Floor")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(style.color)
                .disabled(!attunement.isReady || appState.battle.activeBattle != nil)
            }
        }
        .padding(14)
        .trinketSurface(unlocked ? .elevated : .denseRow)
        .opacity(unlocked ? 1 : 0.7)
        .accessibilityIdentifier(AccessibilityID.Play.aspectFloor(aspect.id.rawValue, floor: floor.floor))
        .animation(reduceMotion ? nil : .smooth, value: unlocked)
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
}
