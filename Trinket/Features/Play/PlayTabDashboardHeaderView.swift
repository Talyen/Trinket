import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct PlayTabDashboardHeaderView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 12) {
            // Event/Offer Banner Hook Point (renders nothing and takes no space currently)
            Color.clear
                .frame(height: 0)

            if appState.showResumeBattleCard {
                ResumeBattleCardView()
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.top, appState.showResumeBattleCard ? 14 : 0)
    }
}

struct ResumeBattleCardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let stageID = appState.activeBattleStageID,
               let stage = GameContent.stage(id: stageID) {
                resumeCard(
                    subtitle: stage.mapLabel + " " + stage.encounterSubjectName,
                    tint: stage.encounter.mapTint
                ) {
                    EncounterArtwork(stage: stage)
                }
            } else if let aspectIDRaw = appState.activeBattleAspectID,
                      let floorNumber = appState.activeBattleAspectFloor,
                      let aspect = GameContent.aspect(id: AspectID(aspectIDRaw)),
                      let floor = GameContent.aspectFloor(aspectID: aspect.id, floor: floorNumber) {
                aspectResumeCard(aspect: aspect, floor: floor, floorNumber: floorNumber)
            } else if let nodeID = appState.shellSession.activeBattleLabyrinthNodeID,
                      let node = appState.labyrinth.node(id: nodeID) {
                labyrinthResumeCard(node: node)
            }
        }
    }

    private func aspectResumeCard(aspect: AspectDefinition, floor: AspectFloor, floorNumber: Int) -> some View {
        let enemyName = GameContent.enemy(matching: floor.enemyID)?.combatant.name
            ?? "Floor \(floorNumber)"
        let style = aspect.keyword.visualStyle
        return resumeCard(
            subtitle: "\(aspect.title) · Floor \(floorNumber) · \(enemyName)",
            tint: style.color
        ) {
            ZStack {
                style.color.opacity(0.35)
                Image(systemName: style.symbolName)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(style.color)
            }
        }
    }

    private func labyrinthResumeCard(node: LabyrinthNode) -> some View {
        let enemyName = node.enemyID.flatMap { GameContent.enemy(matching: $0)?.combatant.name }
        let subtitle = enemyName.map { "\(node.type.title) · \($0)" } ?? node.type.title
        return resumeCard(subtitle: "Labyrinth · \(subtitle)", tint: .orange) {
            ZStack {
                Color.orange.opacity(0.28)
                Image(systemName: node.type.symbolName)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func resumeCard<Artwork: View>(
        subtitle: String,
        tint: Color,
        @ViewBuilder artwork: () -> Artwork
    ) -> some View {
        VStack(spacing: 14) {
            resumeIdentityRow(subtitle: subtitle, artwork: artwork)
            resumeActions(tint: tint)
        }
        .trinketSurface(.elevated)
    }

    private func resumeIdentityRow<Artwork: View>(
        subtitle: String,
        @ViewBuilder artwork: () -> Artwork
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            artwork()
                .frame(width: 120, height: 120)
                .clipShape(TrinketDesign.cardShape)
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.green)
                    Text("IN PROGRESS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.green)
                }

                Text("Resume Battle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                if let elapsedText {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(elapsedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func resumeActions(tint: Color) -> some View {
        VStack(spacing: 8) {
            Button {
                appState.resumeSavedBattle()
            } label: {
                Label("Resume", systemImage: "swords")
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .tint(tint)
            .accessibilityIdentifier("Resume Battle Button")

            Button {
                appState.abandonSavedBattle()
            } label: {
                Label("Abandon", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            // UIStyleCheck: allow - Outlined custom secondary button using plain style.
            .buttonStyle(.plain)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact)
                    .stroke(Color.red.opacity(0.8), lineWidth: 1)
            }
            .foregroundStyle(Color.red)
            .accessibilityIdentifier("Abandon Battle Button")
        }
    }

    private var elapsedText: String? {
        guard let savedAt = appState.activeBattleSavedAt else { return nil }
        let elapsedSeconds = Date.now.timeIntervalSince(savedAt)
        let minutes = Int(elapsedSeconds / 60)
        if minutes < 1 {
            return "Left just now"
        } else if minutes < 60 {
            return "Left \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            let hours = minutes / 60
            return "Left \(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
}
