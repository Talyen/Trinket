import SwiftUI

enum PartyPickerKind: String, Identifiable {
    case hero = "Hero"
    case pet = "Pet"

    var id: String {
        rawValue
    }

    var accessibilityIdentifier: String {
        "\(rawValue) Party Picker"
    }
}

struct StagePreviewSubject {
    let type: String
    let name: String
    let symbolName: String
    let tint: Color
    let combatant: Combatant?
}

struct StagePreviewSheet: View {
    @Environment(AppState.self) private var appState
    @State private var partyPicker: PartyPickerKind?

    let stage: Stage
    let chapter: Chapter
    let onPrimaryAction: () -> Void

    private let scrollCoordinateSpaceName = "StagePreviewScroll"

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let baseHeaderHeight = StagePreviewHeader.headerHeight(forWidth: geometry.size.width)

                ScrollView {
                    VStack(spacing: 0) {
                        StagePreviewHeader(
                            stage: stage,
                            subject: subject,
                            baseHeight: baseHeaderHeight,
                            coordinateSpaceName: scrollCoordinateSpaceName
                        )
                        .accessibilityIdentifier("Stage Preview Header")

                        VStack(alignment: .leading, spacing: 0) {
                            encounterInfoSection
                            partySection
                        }
                        .background(TrinketDesign.Colors.appBackground)
                    }
                    .padding(.bottom, 88)
                }
                .coordinateSpace(name: scrollCoordinateSpaceName)
                .background(TrinketDesign.Colors.appBackground)
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .bottom) {
                    primaryActionBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $partyPicker) { picker in
                PartyPickerSheet(
                    kind: picker,
                    combatants: combatants(for: picker),
                    selectedID: selectedID(for: picker),
                    onSelect: { combatant in
                        select(combatant, for: picker)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var encounterInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encounter")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(stage.flavorText)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Party")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                Button {
                    partyPicker = .hero
                } label: {
                    PartySelectionCard(
                        title: "Hero",
                        combatant: appState.roster.activeHero,
                        accessibilityIdentifier: "Selected Hero Card"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    partyPicker = .pet
                } label: {
                    PartySelectionCard(
                        title: "Pet",
                        combatant: appState.roster.activePet,
                        accessibilityIdentifier: "Selected Pet Card"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var primaryActionBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: onPrimaryAction) {
                Text(stage.encounter.primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            // UIStyleCheck: allow - encounter sheets use the native prominent CTA.
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(chapter.theme.tint)
            .accessibilityIdentifier("\(stage.encounter.primaryActionTitle) Button")
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(TrinketDesign.Colors.appBackground)
    }

    private var subject: StagePreviewSubject {
        switch stage.encounter {
        case .battle:
            if let enemy = stageEnemy {
                return StagePreviewSubject(
                    type: "Enemy",
                    name: enemy.name,
                    symbolName: stage.encounter.symbolName,
                    tint: chapter.theme.tint,
                    combatant: enemy.combatant
                )
            }
            return StagePreviewSubject(
                type: "Enemy",
                name: "Unknown",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.tint,
                combatant: nil
            )
        case .event:
            return StagePreviewSubject(
                type: "Event",
                name: "Mystery",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.secondaryTint,
                combatant: nil
            )
        case .shop:
            return StagePreviewSubject(
                type: "Shop",
                name: "Merchant",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.tint,
                combatant: nil
            )
        case .rest:
            return StagePreviewSubject(
                type: "Rest",
                name: "Moonwell",
                symbolName: stage.encounter.symbolName,
                tint: chapter.theme.secondaryTint,
                combatant: nil
            )
        }
    }

    private var stageEnemy: Enemy? {
        guard let enemyID = stage.encounter.battleEnemyID else { return nil }
        return GameContent.enemy(matching: enemyID)
    }

    private func combatants(for picker: PartyPickerKind) -> [Combatant] {
        switch picker {
        case .hero:
            return appState.roster.heroes
        case .pet:
            return appState.roster.pets
        }
    }

    private func selectedID(for picker: PartyPickerKind) -> String {
        switch picker {
        case .hero:
            return appState.roster.current.activeHeroID
        case .pet:
            return appState.roster.current.activePetID
        }
    }

    private func select(_ combatant: Combatant, for picker: PartyPickerKind) {
        switch picker {
        case .hero:
            appState.roster.setActiveHero(combatant)
        case .pet:
            appState.roster.setActivePet(combatant)
        }
    }
}
