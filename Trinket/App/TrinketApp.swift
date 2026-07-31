import os
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

private let trinketAppLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "TrinketApp"
)

@main
struct TrinketApp: App {
    @State private var appState: AppState?
    @State private var battleSession: BattleSession?
    @State private var bootstrapFailureMessage: String?

    init() {
        var resolvedBattleSession: BattleSession?
        let makeBattleRuntime: (BattleRuntimeDependencies) -> any BattleRuntime = { dependencies in
            let session = Self.makeBattleSession(dependencies: dependencies)
            resolvedBattleSession = session
            return session
        }

        do {
            _appState = try State(initialValue: AppState(
                environment: .shared,
                makeBattleRuntime: makeBattleRuntime
            ))
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
                    shellSessionStore: fallbackShell,
                    makeBattleRuntime: makeBattleRuntime
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
        _battleSession = State(initialValue: resolvedBattleSession)
    }

    var body: some Scene {
        WindowGroup {
            if let appState, let battleSession {
                PreparedAppRoot(
                    appState: appState,
                    battleSession: battleSession,
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
        let activeParty = [appState.playerSave.roster.activeHero, appState.playerSave.roster.activeCompanion]
            .compactMap(\.artReference)
            .flatMap { reference in
                [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
            }
        let activeEnemy = appState.playerSave.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return activeParty + enemyNames
    }

    private static func makeBattleSession(
        dependencies: BattleRuntimeDependencies
    ) -> BattleSession {
        BattleSession(
            presentationEnvironment: BattlePresentationEnvironment(
                playSFX: dependencies.playSFX,
                warmSFX: dependencies.warmSFX,
                hapticsEnabled: dependencies.hapticsEnabled,
                effectsVolume: dependencies.effectsVolume,
                shouldAutoSkipUltimateCinematic: dependencies.shouldAutoSkipUltimateCinematic
            )
        )
    }
}

private struct PreparedAppRoot: View {
    /// Avoid a flash when launch prep finishes before the screen can register.
    private static let minimumLaunchDisplayDuration: Duration = .seconds(1)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @State private var artworkCache = PreparedArtworkCache.shared
    @State private var isResourcePreparationComplete = false
    @State private var areCastEffectsPrepared = false

    let appState: AppState
    let battleSession: BattleSession
    let priorityImageNames: [String]

    var body: some View {
        Group {
            if isPreparationComplete {
                ContentView()
                    .environment(battleSession)
            } else {
                ZStack {
                    LaunchWarmupView()
                    if shouldPrepareCastEffects, !areCastEffectsPrepared {
                        CardCastEffectsPrewarmView {
                            areCastEffectsPrepared = true
                        }
                    }
                }
            }
        }
        .environment(appState)
        .environment(appState.play)
        .environment(appState.play.journey)
        .environment(appState.play.labyrinth)
        .environment(appState.play.spires)
        .environment(appState.play.encounters)
        .environment(appState.options)
        .environment(appState.playerSave)
        .environment(\.playSFX) { id, volume in
            appState.sfxPlayer.play(id, volume: volume)
        }
        #if DEBUG
        .debugFPSOverlay()
        #endif
        .task {
            MetricKitSubscriber.shared.start()
            guard !isResourcePreparationComplete else { return }
            appState.prepareLaunchPerformanceResources()
            // Align the minimum hold with first paint (same yield as the
            // progress fill) so a warm cache cannot dismiss before the bar runs.
            await Task.yield()
            let displayedAt = ContinuousClock.now
            await BattlePresentationWarmup.prepareAndWait(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
            await artworkCache.prepareAll(priorityImageNames: priorityImageNames)
            guard !Task.isCancelled else { return }
            if let stageID = appState.playerSave.journey.activeStageID,
               let stage = GameContent.stage(id: stageID) {
                appState.play.journey.prepareBattle(for: stage)
            }
            let hold = Self.minimumLaunchDisplayDuration
                - displayedAt.duration(to: ContinuousClock.now)
            if hold > .zero {
                try? await Task.sleep(for: hold)
            }
            guard !Task.isCancelled else { return }
            isResourcePreparationComplete = true
        }
    }

    private var shouldPrepareCastEffects: Bool {
        // Always prime the live TimelineView / Canvas cast path. Cold-cast scenarios
        // still skip dissolve texture prepare inside CardCastEffectsPrewarmView.
        true
    }

    private var isPreparationComplete: Bool {
        isResourcePreparationComplete && (areCastEffectsPrepared || !shouldPrepareCastEffects)
    }
}
