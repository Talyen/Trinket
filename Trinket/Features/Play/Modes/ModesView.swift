import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct ModesView: View {
    @Environment(AppState.self) private var appState

    private var modesUnlocked: Bool {
        ModesUnlock.isUnlocked(journey: appState.journey.current)
    }

    var body: some View {
        Group {
            if modesUnlocked {
                unlockedList
            } else {
                ContentUnavailableView(
                    "Modes Locked",
                    systemImage: "lock.fill",
                    description: Text(ModesUnlock.unlockHint)
                )
            }
        }
        .navigationTitle("Modes")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.denseList)
        .accessibilityIdentifier(AccessibilityID.Play.modesScreen)
    }

    private var unlockedList: some View {
        List {
            Section {
                NavigationLink {
                    AspectsHubView()
                } label: {
                    modeRow(
                        title: "Aspects",
                        subtitle: aspectsSubtitle,
                        systemImage: "sparkles"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)

                lockedModeRow(
                    title: "Reliquary Gauntlet",
                    subtitle: "Opens later",
                    systemImage: "shield.lefthalf.filled"
                )
                .disabled(true)
                lockedModeRow(
                    title: "Astral Hunt",
                    subtitle: "Opens later",
                    systemImage: "scope"
                )
                .disabled(true)

                labyrinthRow
            } footer: {
                Text("Other paths. Same battles. Different reasons to fight.")
            }
        }
    }

    private var aspectsSubtitle: String {
        let progress = appState.aspects.current
        if let teaser = GameContent.aspects
            .filter({ AspectUnlock.isUnlocked($0, progress: progress) })
            .compactMap({ aspect -> String? in
                let cleared = progress.highestClearedFloor(for: aspect.id.rawValue)
                guard cleared > 0 else { return nil }
                if cleared >= aspect.floorCount {
                    return "\(aspect.title) · Cleared"
                }
                return "\(aspect.title) · Floor \(cleared + 1)"
            })
            .first {
            return teaser
        }
        return "Climb by affinity. Attune a Hero and Pet."
    }

    @ViewBuilder
    private var labyrinthRow: some View {
        let unlocked = appState.isLabyrinthUnlocked
        let depth = appState.labyrinth.deepestDepth
        if unlocked {
            NavigationLink {
                LabyrinthMapView()
            } label: {
                modeRow(
                    title: "The Labyrinth",
                    subtitle: depth > 0
                        ? "Depth \(depth). An endless descent."
                        : "An endless descent. Biomes, modifiers, finds.",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            }
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
        } else {
            lockedModeRow(
                title: "The Labyrinth",
                subtitle: LabyrinthUnlock.unlockHint(
                    journey: appState.journey.current,
                    aspects: appState.aspects.current
                ),
                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
            .disabled(true)
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
        }
    }

    private func modeRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func lockedModeRow(title: String, subtitle: String, systemImage: String) -> some View {
        modeRow(title: title, subtitle: subtitle, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .opacity(0.72)
    }
}
