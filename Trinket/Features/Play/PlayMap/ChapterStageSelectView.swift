import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Single-stage Campaign screen — current chapter + the stage in front of you.
struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var prepareBattleStage: Stage?
    /// Reference box so dismiss observers can read the queued stage (plain `@State`
    /// Optional can still be stale in the same update that clears the sheet item).
    @State private var pendingBattleStart = PendingBattleStart()

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    var body: some View {
        Group {
            if let stage = activeStage {
                stageContent(stage)
                    .id(stage.id)
                    .transition(stageTransition)
            } else {
                ContentUnavailableView(
                    "Chapter Complete",
                    systemImage: "flag.checkered",
                    description: Text("You've cleared every stage in this chapter.")
                )
            }
        }
        .animation(stageAnimation, value: activeStage?.id)
        .navigationTitle(chapterTitle)
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.playJourney)
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text(chapterTitle)
                .accessibilityIdentifier(
                    AccessibilityID.Play.chapterHeader(number: appState.playChapter.number)
                )
                .accessibilityAddTraits(.isHeader)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(false)
        }
        .onAppear {
            updateMusicPreview()
        }
        .onChange(of: appState.journey.current) { _, _ in
            updateMusicPreview()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
        .sheet(item: $prepareBattleStage, onDismiss: startPendingBattleIfNeeded) { stage in
            BattlePartySheet(
                title: stage.encounterSubjectName,
                subtitle: stage.mapLabel,
                accentColor: stage.encounter.mapTint,
                initialHero: appState.roster.activeHero,
                initialPet: appState.roster.activePet,
                onStart: {
                    pendingBattleStart.stage = stage
                    prepareBattleStage = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var chapterTitle: String {
        "Chapter \(appState.playChapter.number)"
    }

    private var activeStage: Stage? {
        guard let stageID = appState.journey.current.activeStageID else { return nil }
        return GameContent.stage(id: stageID)
    }

    private func stageContent(_ stage: Stage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CurrentStageCard(
                    stage: stage,
                    onEnemyTap: { onEnemyTap(stage) },
                    onPrimaryAction: { handlePrimaryAction(stage) }
                )
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func handlePrimaryAction(_ stage: Stage) {
        if stage.encounter.battleEnemyID != nil {
            prepareBattleStage = stage
        } else {
            onStageTap(stage)
        }
    }

    private func startPendingBattleIfNeeded() {
        guard let stage = pendingBattleStart.stage else { return }
        pendingBattleStart.stage = nil
        onStageTap(stage)
    }

    private func updateMusicPreview() {
        appState.battle.setMusicPreview(for: activeStage)
    }

    private var stageAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)
    }

    private var stageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
    }
}

/// Mutable box for a stage queued across party-sheet dismiss (avoids `@State` staleness).
@MainActor
private final class PendingBattleStart {
    var stage: Stage?
}
