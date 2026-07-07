import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

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
        if let stageID = appState.sessionState.activeBattleStageID,
           let stage = GameContent.stage(id: stageID) {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    // Left image
                    EncounterArtwork(stage: stage)
                        .frame(width: 120, height: 120)
                        .clipShape(TrinketDesign.cardShape)
                        .overlay {
                            TrinketDesign.cardShape
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }

                    // Right text column
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

                        Text(stage.mapLabel + " " + stage.encounterSubjectName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)

                        if let elapsedText = elapsedText {
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

                // Bottom buttons
                VStack(spacing: 8) {
                    Button {
                        appState.resumeSavedBattle()
                    } label: {
                        Label("Resume", systemImage: "swords")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .tint(stage.encounter.mapTint)
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
            .trinketSurface(.elevated)
        }
    }

    private var elapsedText: String? {
        guard let savedAt = appState.sessionState.activeBattleSavedAt else { return nil }
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
