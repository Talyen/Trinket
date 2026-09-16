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
    /// Computed once from the resolved state during init; never mutated after.
    private let launchPriorityImageNames: [String]

    static let battleRuntimeTypeMessage = "AppState battle runtime must be BattleSession"

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
        // launch artwork census once from the resolved state. Bootstrap is a
        // pure static step so init assigns every property (including the
        // launch census let) before touching self.
        let bootstrap = Self.bootstrapState(makeState: makeState)
        if let state = bootstrap.state {
            launchPriorityImageNames = LaunchArtworkCensus.priorityImageNames(for: state)
            _appState = State(initialValue: state)
            cloudNotifications.store = state.playerSave
        } else {
            launchPriorityImageNames = []
            _appState = State(initialValue: nil)
            _bootstrapFailureMessage = State(initialValue: bootstrap.failureMessage)
        }
        MetricKitSubscriber.shared.start()
    }

    private struct BootstrapResult {
        var state: AppState?
        var failureMessage = "Progress storage could not be started on this device."
    }

    /// Bootstrap with in-memory fallback. Extracted so the primary and fallback
    /// paths share one logging shape instead of a nested do/catch. Takes no
    /// self state so init can assign properties (including lets) afterwards.
    private static func bootstrapState(
        makeState: (PlayerSaveStore?) throws -> AppState,
    ) -> BootstrapResult {
        do {
            return try BootstrapResult(state: makeState(nil))
        } catch {
            trinketAppLogger.error(
                "AppState bootstrap failed: \(String(describing: error), privacy: .public)",
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                return try BootstrapResult(state: makeState(fallbackSave))
            } catch {
                trinketAppLogger.fault(
                    "AppState in-memory fallback failed: \(error.localizedDescription, privacy: .public)",
                )
                return BootstrapResult(
                    state: nil,
                    failureMessage: "Progress storage could not be started on this device. Try freeing space or reinstalling, then launch again.",
                )
            }
        }
    }

    private static func configureBattleProgression(_ runtime: any BattleRuntime, play: PlaySession) {
        guard let battle = runtime as? BattleSession else {
            preconditionFailure(battleRuntimeTypeMessage)
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
                    // Intentional: Trinket hides scroll indicators app-wide as an
                    // art-forward choice; individual screens must not re-enable
                    // them without product approval.
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
        // Intentional: game screens manage their own chrome; system overlays
        // stay hidden app-wide unless product approves a scoped exception.
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
            preconditionFailure(TrinketApp.battleRuntimeTypeMessage)
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
            if !preparation.didCompleteLaunchPreparation || preparation.launchEncounterToken != nil {
                launchCover
                    .allowsHitTesting(true)
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
            await runPurchaseSync()
        }
        .onChange(of: appState.fullGame.ownership) { _, _ in
            appState.synchronizePurchaseAccess()
        }
        .task {
            await runPreparationDelay()
        }
        .task {
            await runResourcePreparation()
        }
        .onChange(of: isPreparationComplete, initial: false) { _, isComplete in
            guard isComplete, !preparation.didCompleteLaunchPreparation else { return }
            // Capture the encounter identity once so later encounters cannot
            // reopen the cover; the retained underlay is decorative only.
            preparation.acknowledge(.launchEncounterTokenChanged(
                appState.shellSession.selectedTab == .play ? activeEncounterID : nil,
            ))
            preparation.acknowledge(.launchPreparationComplete)
        }
        .onChange(of: activeEncounterID) { _, encounterID in
            if preparation.launchEncounterToken != encounterID {
                preparation.acknowledge(.launchEncounterTokenChanged(nil))
            }
        }
    }

    /// Launch cover with stable view identity: before readiness it carries
    /// the loading identifier UITests wait on; after readiness the retained
    /// underlay becomes decorative, switches identifier, and is hidden from accessibility.
    private var launchCover: some View {
        LaunchWarmupView(
            isMinimumLoadingTimeComplete: preparation.isMinimumLoadingTimeComplete,
        ) {
            preparation.acknowledge(.minimumLoadingTimeComplete)
        }
        .accessibilityIdentifier(
            preparation.didCompleteLaunchPreparation
                ? "Launch Warmup Decorative"
                : AccessibilityID.Screen.launchWarmup,
        )
        .accessibilityHidden(preparation.didCompleteLaunchPreparation)
    }

    private func runPurchaseSync() async {
        await appState.fullGame.start()
        appState.synchronizePurchaseAccess()
    }

    private func runPreparationDelay() async {
        guard !preparation.isPreparationDelayComplete else { return }
        try? await Task.sleep(for: .seconds(AppEnvironment.shared.launchPreparationDelay))
        guard !Task.isCancelled else { return }
        preparation.acknowledge(.preparationDelayComplete)
    }

    /// Resource phase ordering is intentional: synchronous performance resources
    /// first, then parallel battle textures + launch artwork, then journey prep
    /// and battle presentation assets. Do not serialize the parallel pair or
    /// move battle-asset prep before them without measuring first frame.
    private func runResourcePreparation() async {
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
