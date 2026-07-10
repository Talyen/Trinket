import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

/// Peer mode picker for the Play tab — Campaign, Aspects, and Labyrinth are equals.
struct PlayModeHubView: View {
    @Environment(AppState.self) private var appState

    let onOpenCampaign: () -> Void
    let onOpenAspects: () -> Void
    let onOpenLabyrinth: () -> Void

    private var modesUnlocked: Bool {
        ModesUnlock.isUnlocked(journey: appState.journey.current)
    }

    var body: some View {
        List {
            Section {
                Button(action: onOpenCampaign) {
                    modeRow(
                        title: "Campaign",
                        subtitle: campaignSubtitle,
                        systemImage: "map.fill"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Play.campaignModeCard)

                aspectsRow
                labyrinthRow

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
            } footer: {
                Text("Choose a path. Same battles. Different reasons to fight.")
            }
        }
        .navigationTitle("Play")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.denseList)
        .accessibilityIdentifier(AccessibilityID.Play.modesScreen)
    }

    private var campaignSubtitle: String {
        let chapter = appState.playChapter
        if let stageID = appState.journey.current.activeStageID,
           let stage = GameContent.stage(id: stageID) {
            return "Chapter \(chapter.number) · \(stage.mapLabel)"
        }
        return "Chapter \(chapter.number) · Complete"
    }

    @ViewBuilder
    private var aspectsRow: some View {
        if modesUnlocked {
            Button(action: onOpenAspects) {
                modeRow(
                    title: "Aspects",
                    subtitle: aspectsSubtitle,
                    systemImage: "sparkles"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
        } else {
            lockedModeRow(
                title: "Aspects",
                subtitle: "Climb by affinity. Attune a Hero and Pet.",
                systemImage: "sparkles",
                accessibilityHint: ModesUnlock.unlockHint
            )
            .disabled(true)
            .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
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
            Button(action: onOpenLabyrinth) {
                modeRow(
                    title: "The Labyrinth",
                    subtitle: depth > 0
                        ? "Depth \(depth). An endless descent."
                        : "An endless descent. Biomes, modifiers, finds.",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
        } else {
            lockedModeRow(
                title: "The Labyrinth",
                subtitle: "An endless descent. Biomes, modifiers, finds.",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                accessibilityHint: LabyrinthUnlock.unlockHint(
                    journey: appState.journey.current,
                    aspects: appState.aspects.current
                )
            )
            .disabled(true)
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
        }
    }

    private func modeRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .trinketTypography(.button)
                Text(subtitle)
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func lockedModeRow(
        title: String,
        subtitle: String,
        systemImage: String,
        accessibilityHint: String? = nil
    ) -> some View {
        modeRow(title: title, subtitle: subtitle, systemImage: systemImage)
            .trinketLockedCardEffect(
                isLocked: true,
                text: "Locked",
                cornerRadius: TrinketDesign.Corners.compact
            )
            .accessibilityHint(accessibilityHint ?? subtitle)
    }
}
