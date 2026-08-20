import os
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
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
        let environment = AppEnvironment.shared
        var concreteBattleSession: BattleSession?
        let makeBattleRuntime: (BattleRuntimeDependencies) -> any BattleRuntime = { dependencies in
            let session = BattleSession(
                autoEndTurnDelay: environment.battleTickInterval
                    ?? BattleSession.autoEndTurnDelay,
                presentationEnvironment: dependencies
            )
            concreteBattleSession = session
            return session
        }

        do {
            let state = try AppState(
                environment: environment,
                makeBattleRuntime: makeBattleRuntime
            )
            _appState = State(initialValue: state)
            _battleSession = State(initialValue: concreteBattleSession)
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)"
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let state = try AppState(
                    environment: environment,
                    playerSave: fallbackSave,
                    makeBattleRuntime: makeBattleRuntime
                )
                _appState = State(initialValue: state)
                _battleSession = State(initialValue: concreteBattleSession)
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
        let starterChoices = (GameContent.starterHeroes + GameContent.starterCompanions)
            .compactMap { $0.artReference?.thumbnailImageName }
        let activeEnemy = appState.playerSave.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference(worldSeed: appState.playerSave.worldSeed)
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return Array(
            Set(activeParty + starterChoices + enemyNames + rootTabImageNames(for: appState))
        ).sorted()
    }

    /// One centralized strong working set for the first interactive surfaces.
    /// Each surface uses the smallest variant that remains sharp at its rendered size.
    private func rootTabImageNames(for appState: AppState) -> [String] {
        let roster = appState.playerSave.roster
        let inventory = appState.playerSave.inventory
        let shelfLimit = TrinketDesign.Metrics.collectionShelfPreviewLimit

        let collectionCombatants = (
            Array(roster.collectionHeroes.prefix(shelfLimit))
                + Array(roster.collectionCompanions.prefix(shelfLimit))
        ).compactMap { $0.artReference?.thumbnailImageName }
        let collectionItems = inventory.items.prefix(shelfLimit).compactMap {
            $0.artReference?.thumbnailImageName
        }
        let playModeCards = ["gameModeCampaign", "gameModeExplore"].compactMap {
            ArtCatalog.backgroundArtByID[$0]?.imageName
        }
        let homesteadCards = HomesteadNodeCategory.allCases.compactMap {
            ArtCatalog.backgroundArtByID[$0.artID]?.imageName
        }
        let homesteadHero = ArtCatalog.backgroundArtByID["homestead"]?.imageName
        let resourceIcons = ArtCatalog.resourceArtByID.values.map(\.imageName)

        let chapter = appState.play.journey.playChapter
        let campaignHero = (
            ArtCatalog.backgroundArtByID[chapter.id]
                ?? ArtCatalog.backgroundArtByID["chapter-1"]
        )?.imageName
        let campaignRows = chapter.stages.compactMap { stage -> String? in
            if let combatant = stage.encounterCombatantArtReference(
                worldSeed: appState.playerSave.worldSeed
            ) {
                return combatant.thumbnailImageName
            }
            return stage.encounterArtReference?.thumbnailImageName
        }

        return collectionCombatants
            + collectionItems
            + playModeCards
            + homesteadCards
            + resourceIcons
            + campaignRows
            + [homesteadHero, campaignHero].compactMap(\.self)
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
        .environment(appState.shellSession)
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
            defer {
                artworkCache.releasePins(names: priorityImageNames)
            }
            appState.prepareLaunchPerformanceResources()
            battleSession.prepareAllBattleCinematics()
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
            // Capture the first interactive root separately from the decode peak.
            // Two yields let ContentView install its initial hierarchy first.
            await Task.yield()
            await Task.yield()
            artworkCache.reportMemorySnapshot(label: "interactiveRoot")
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
