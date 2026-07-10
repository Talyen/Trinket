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
                    systemImage: "shield.lefthalf.filled"
                )
                .disabled(true)
                lockedModeRow(
                    title: "Astral Hunt",
                    systemImage: "scope"
                )
                .disabled(true)
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
                    systemImage: "sparkles"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
        } else {
            lockedModeRow(
                title: "Aspects",
                systemImage: "sparkles",
                accessibilityHint: ModesUnlock.unlockHint
            )
            .disabled(true)
            .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
        }
    }

    @ViewBuilder
    private var labyrinthRow: some View {
        if appState.isLabyrinthUnlocked {
            Button(action: onOpenLabyrinth) {
                modeRow(
                    title: "The Labyrinth",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
        } else {
            lockedModeRow(
                title: "The Labyrinth",
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

    private func modeRow(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isLocked: Bool = false
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .trinketTypography(.button)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func lockedModeRow(
        title: String,
        systemImage: String,
        accessibilityHint: String? = nil
    ) -> some View {
        modeRow(title: title, systemImage: systemImage, isLocked: true)
            .accessibilityHint(accessibilityHint ?? "Locked")
    }
}
