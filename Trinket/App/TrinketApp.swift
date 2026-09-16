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
    @UIApplicationDelegateAdaptor(CloudNotificationDelegate.self) private var cloudNotifications
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
            let state = try AppState(
                environment: environment,
                playerSave: store,
                makeBattleRuntime: makeBattleRuntime,
                configureBattleRuntime: Self.configureBattleProgression,
            )
            if environment.launchScreen == .battleVictory {
                (state.play.battle as? BattleSession)?.presentLaunchVictory()
            }
            #if DEBUG
            PerformanceFixtures.install(in: state)
            if environment.launchScreen == .battleDefeat || environment.launchScreen == .battleDefeatSaveFailure {
                (state.play.battle as? BattleSession)?.presentLaunchDefeat()
                state.playerSave.forcesNextSaveFailure = environment.launchScreen == .battleDefeatSaveFailure
            }
            #endif
            return state
        }

        // Resolve state first (with in-memory fallback), then compute the
        // launch artwork census once from the resolved state.
        let resolvedState: AppState?
        do {
            let state = try makeState(nil)
            cloudNotifications.store = state.playerSave
            resolvedState = state
        } catch {
            trinketAppLogger.error(
                "AppState bootstrap failed: \(String(describing: error), privacy: .public)",
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let state = try makeState(fallbackSave)
                cloudNotifications.store = state.playerSave
                resolvedState = state
            } catch {
                trinketAppLogger.fault(
                    "AppState in-memory fallback failed: \(error.localizedDescription, privacy: .public)",
                )
                resolvedState = nil
                _bootstrapFailureMessage = State(
                    initialValue: "Progress storage could not be started on this device. Try freeing space or reinstalling, then launch again.",
                )
            }
        }
        if let resolvedState {
            _appState = State(initialValue: resolvedState)
            _launchPriorityImageNames = State(initialValue: LaunchArtworkCensus.priorityImageNames(for: resolvedState))
        } else {
            _appState = State(initialValue: nil)
        }
        MetricKitSubscriber.shared.start()
    }

    private static func configureBattleProgression(_ runtime: any BattleRuntime, play: PlaySession) {
        guard let battle = runtime as? BattleSession else {
            preconditionFailure("AppState battle runtime must be BattleSession")
        }
        battle.configureProgression(
            presentation: { [weak play] configuration in
                play?.battlePresentation(for: configuration)
            },
            settleRewards: { [weak play] configuration, gold in
                play?.settleBattleRewards(configuration, battleGold: gold)
            },
            completeVictory: { [weak play] configuration, gold, settlement, defersExit in
                play?.completeActiveBattle(
                    configuration, battleGold: gold,
                    materialRewards: settlement?.award.materials, settlement: settlement,
                    defersPresentationExit: defersExit,
                ) ?? .unavailable
            },
            settleDefeat: { [weak play] configuration in
                play?.settleDefeatRewards(configuration)
            },
            completeDefeat: { [weak play] configuration, settlement, action in
                play?.completeDefeat(configuration, settlement: settlement, action: action) ?? .unavailable
            },
            finishPresentation: { [weak play] id in
                play?.finishBattleRewardPresentation(configurationID: id)
            },
        )
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
    @State private var preparation: LaunchPreparation

    let appState: AppState
    let priorityImageNames: [String]

    init(appState: AppState, priorityImageNames: [String]) {
        self.appState = appState
        self.priorityImageNames = priorityImageNames
        _preparation = State(initialValue: LaunchPreparation(
            isPreparationDelayComplete: AppEnvironment.shared.launchPreparationDelay == 0,
        ))
    }

    private var battleSession: BattleSession {
        guard let session = appState.play.battle as? BattleSession else {
            preconditionFailure("AppState battle runtime must be BattleSession")
        }
        return session
    }

    private var starterSelectionComplete: Bool {
        appState.playerSave.starterSelection.phase == .complete
    }

    private var shouldWarmHiddenTabs: Bool {
        preparation.shouldMountRoot
            && starterSelectionComplete
            && !preparation.didWarmHiddenTabs
    }

    var body: some View {
        ZStack {
            if preparation.shouldMountRoot {
                ContentView {
                    preparation.acknowledge(.selectedRootLaidOut)
                }
            }
            if shouldWarmHiddenTabs {
                HiddenTabPrewarm {
                    preparation.acknowledge(.hiddenTabsWarmed)
                }
            }
            if !preparation.didCompleteLaunchPreparation || preparation.retainedLaunchEncounterID != nil {
                LaunchWarmupView {
                    preparation.acknowledge(.minimumLoadingTimeComplete)
                }
                .allowsHitTesting(true)
                .accessibilityIdentifier(preparation.didCompleteLaunchPreparation ? "" : AccessibilityID.Screen.launchWarmup)
                .accessibilityHidden(preparation.didCompleteLaunchPreparation)
                if !preparation.areCastEffectsPrepared {
                    CardCastEffectsPrewarmView(isRenderingEnabled: areRootLayoutsPrepared) {
                        preparation.acknowledge(.castEffectsPrepared)
                    }
                }
            }
        }
        .trinketDecorativeMotion(preparation.didCompleteLaunchPreparation)
        .environment(\.isLaunchPresentationReady, preparation.didCompleteLaunchPreparation)
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
            guard !preparation.isPreparationDelayComplete else { return }
            try? await Task.sleep(for: .seconds(AppEnvironment.shared.launchPreparationDelay))
            guard !Task.isCancelled else { return }
            preparation.acknowledge(.preparationDelayComplete)
        }
        .task {
            guard !preparation.isResourcePreparationComplete else { return }
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
            await battleSession.prepareBattlePresentationAssets(displayScale: displayScale)
            guard !Task.isCancelled else { return }
            preparation.acknowledge(.resourcesReady)
            artworkCache.reportMemorySnapshot(label: "interactiveRoot")
        }
        .onChange(of: isPreparationComplete, initial: true) { _, isComplete in
            guard isComplete, !preparation.didCompleteLaunchPreparation else { return }
            if appState.shellSession.selectedTab == .play {
                preparation.retainedLaunchEncounterID = activeEncounterID
            }
            preparation.didCompleteLaunchPreparation = true
        }
        .onChange(of: activeEncounterID) { _, encounterID in
            if preparation.retainedLaunchEncounterID != encounterID {
                preparation.retainedLaunchEncounterID = nil
            }
        }
    }

    private var activeEncounterID: ObjectIdentifier? {
        if let mystery = appState.play.encounters.activeMysteryEncounter {
            return ObjectIdentifier(mystery)
        }
        if let shop = appState.play.encounters.activeShopEncounter {
            return ObjectIdentifier(shop)
        }
        return nil
    }

    private var areRootLayoutsPrepared: Bool {
        preparation.areRootLayoutsPrepared(starterSelectionComplete: starterSelectionComplete)
    }

    private var isPreparationComplete: Bool {
        preparation.isPreparationComplete(starterSelectionComplete: starterSelectionComplete)
    }
}
