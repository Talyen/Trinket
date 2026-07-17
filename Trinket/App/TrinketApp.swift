import os
import SwiftUI
import TrinketContent
import TrinketPersistence

private let trinketAppLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "TrinketApp"
)

@main
struct TrinketApp: App {
    @State private var appState: AppState?
    @State private var bootstrapFailureMessage: String?

    init() {
        do {
            _appState = try State(initialValue: AppState(environment: .shared))
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)"
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let fallbackShell = try PlayerShellSessionStore(inMemoryOnly: true)
                _appState = try State(initialValue: AppState(
                    environment: .shared,
                    playerSave: fallbackSave,
                    shellSessionStore: fallbackShell
                ))
            } catch {
                trinketAppLogger.fault(
                    "AppState in-memory fallback failed: \(error.localizedDescription, privacy: .public)"
                )
                _appState = State(initialValue: nil)
                _bootstrapFailureMessage = State(
                    initialValue: "Progress storage could not be started on this device. Try freeing space or reinstalling, then launch again."
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let appState {
                PreparedAppRoot(
                    appState: appState,
                    priorityImageNames: priorityImageNames(for: appState)
                )
            } else {
                AppBootstrapFailureView(
                    message: bootstrapFailureMessage
                        ?? "Progress storage could not be started on this device."
                )
            }
        }
    }

    private func priorityImageNames(for appState: AppState) -> [String] {
        let activeParty = [appState.roster.activeHero, appState.roster.activeCompanion]
            .compactMap(\.artReference)
            .flatMap { reference in
                [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
            }
        let activeEnemy = appState.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return activeParty + enemyNames
    }
}

private struct PreparedAppRoot: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @State private var artworkCache = PreparedArtworkCache.shared
    @State private var isResourcePreparationComplete = false
    @State private var areCastEffectsPrepared = false

    let appState: AppState
    let priorityImageNames: [String]

    var body: some View {
        Group {
            if isPreparationComplete {
                ContentView()
            } else {
                ZStack {
                    LaunchWarmupView(progress: artworkCache.progress)
                    if shouldPrepareCastEffects, !areCastEffectsPrepared {
                        CardCastEffectsPrewarmView {
                            areCastEffectsPrepared = true
                        }
                    }
                }
            }
        }
        .environment(appState)
        #if DEBUG
            .debugFPSOverlay()
        #endif
            .task {
                MetricKitHitchSubscriber.shared.start()
                guard !isResourcePreparationComplete else { return }
                appState.prepareLaunchPerformanceResources()
                await BattlePresentationWarmup.prepareForLaunch(
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
                await artworkCache.prepareAll(priorityImageNames: priorityImageNames)
                guard !Task.isCancelled else { return }
                if let stageID = appState.journey.activeStageID,
                   let stage = GameContent.stage(id: stageID) {
                    appState.prepareBattle(for: stage)
                }
                isResourcePreparationComplete = true
            }
    }

    private var shouldPrepareCastEffects: Bool {
        AppEnvironment.shared.battlePerformanceScenario != .firstCardCastCold
    }

    private var isPreparationComplete: Bool {
        isResourcePreparationComplete && (areCastEffectsPrepared || !shouldPrepareCastEffects)
    }
}
