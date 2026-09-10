import BattleEngine
import os
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

private let trinketAppLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "TrinketApp",
)

@main
struct TrinketApp: App {
    @State private var appState: AppState?
    @State private var bootstrapFailureMessage: String?
    @State private var launchPriorityImageNames: [String] = []

    init() {
        let environment = AppEnvironment.shared
        let makeBattleRuntime: (BattleRuntimeDependencies) -> any BattleRuntime = { dependencies in
            BattleSession(
                autoEndTurnDelay: environment.battleTickInterval ?? 0.4,
                presentationEnvironment: dependencies,
            )
        }
        func makeState(_ store: PlayerSaveStore?) throws -> AppState {
            if let store {
                try AppState(
                    environment: environment,
                    playerSave: store,
                    makeBattleRuntime: makeBattleRuntime,
                )
            } else {
                try AppState(
                    environment: environment,
                    makeBattleRuntime: makeBattleRuntime,
                )
            }
        }

        do {
            let state = try makeState(nil)
            _appState = State(initialValue: state)
            _launchPriorityImageNames = State(initialValue: LaunchArtworkCensus.priorityImageNames(for: state))
        } catch {
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)",
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let state = try makeState(fallbackSave)
                _appState = State(initialValue: state)
                _launchPriorityImageNames = State(initialValue: LaunchArtworkCensus.priorityImageNames(for: state))
            } catch {
                trinketAppLogger.fault(
                    "AppState in-memory fallback failed: \(error.localizedDescription, privacy: .public)",
                )
                _appState = State(initialValue: nil)
                _bootstrapFailureMessage = State(
                    initialValue: "Progress storage could not be started on this device. Try freeing space or reinstalling, then launch again.",
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let appState {
                    PreparedAppRoot(
                        appState: appState,
                        priorityImageNames: launchPriorityImageNames,
                    )
                    .scrollIndicators(.never)
                } else {
                    AppBootstrapFailureView(
                        message: bootstrapFailureMessage
                            ?? "Progress storage could not be started on this device.",
                    )
                }
            }
            .preferredColorScheme(.dark)
        }
        .persistentSystemOverlays(.hidden)
    }
}

private struct AppBootstrapFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Can't Open Trinket",
            systemImage: "exclamationmark.triangle",
            description: Text(message),
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PreparedAppRoot: View {
    @Environment(\.displayScale) private var displayScale
    private let artworkCache = PreparedArtworkCache.shared
    @State private var isResourcePreparationComplete = false
    @State private var isMinimumLoadingTimeComplete = false
    @State private var areCastEffectsPrepared = false
    @State private var didWarmHiddenTabs = false

    let appState: AppState
    let priorityImageNames: [String]

    private var battleSession: BattleSession {
        guard let session = appState.play.battle as? BattleSession else {
            preconditionFailure("AppState battle runtime must be BattleSession")
        }
        return session
    }

    private var shouldWarmHiddenTabs: Bool {
        appState.playerSave.starterSelection.phase == .complete && !didWarmHiddenTabs
    }

    var body: some View {
        ZStack {
            if isResourcePreparationComplete {
                ContentView()
            }
            if shouldWarmHiddenTabs {
                HiddenTabPrewarm {
                    didWarmHiddenTabs = true
                }
            }
            if !isPreparationComplete {
                LaunchWarmupView {
                    isMinimumLoadingTimeComplete = true
                }
                .allowsHitTesting(true)
                if !areCastEffectsPrepared {
                    CardCastEffectsPrewarmView {
                        areCastEffectsPrepared = true
                    }
                }
            }
        }
        .environment(appState)
        .environment(appState.shellSession)
        .environment(appState.play)
        .environment(appState.play.journey)
        .environment(appState.play.labyrinth)
        .environment(appState.play.spires)
        .environment(appState.play.contracts)
        .environment(appState.play.encounters)
        .environment(appState.fullGame)
        .environment(appState.options)
        .environment(appState.playerSave)
        .environment(battleSession)
        .environment(\.playSFX) { id, volume in
            appState.sfxPlayer.play(id, volume: volume)
        }
        #if DEBUG
        .debugFPSOverlay()
        #endif
        .task {
            await appState.fullGame.start()
            appState.synchronizePurchaseAccess()
        }
        .onChange(of: appState.fullGame.ownership) { _, _ in
            appState.synchronizePurchaseAccess()
        }
        .task {
            MetricKitSubscriber.shared.start()
            guard !isResourcePreparationComplete else { return }
            appState.prepareLaunchPerformanceResources()
            async let battleTextures: Void = BattlePresentationWarmup.prepareAndWait(displayScale: displayScale)
            async let launchArtwork: Void = artworkCache.prepareAll(priorityImageNames: priorityImageNames)
            await battleTextures
            await launchArtwork
            guard !Task.isCancelled else { return }
            if let stageID = appState.playerSave.journey.activeStageID,
               let stage = GameContent.stage(id: stageID) {
                appState.play.journey.prepareBattle(for: stage)
            }
            isResourcePreparationComplete = true
            artworkCache.reportMemorySnapshot(label: "interactiveRoot")
        }
        .task(id: shouldWarmHiddenTabs) {
            guard shouldWarmHiddenTabs else { return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            didWarmHiddenTabs = true
        }
    }

    private var isPreparationComplete: Bool {
        isResourcePreparationComplete
            && isMinimumLoadingTimeComplete
            && areCastEffectsPrepared
    }
}
