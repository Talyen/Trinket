import BattleEngine
import os
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketDesignSystem
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
            _launchPriorityImageNames = State(initialValue: Self.priorityImageNames(for: state))
        } catch {
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)",
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let state = try makeState(fallbackSave)
                _appState = State(initialValue: state)
                _launchPriorityImageNames = State(initialValue: Self.priorityImageNames(for: state))
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
        .persistentSystemOverlays(.hidden)
    }

    private static func priorityImageNames(for appState: AppState) -> [String] {
        let activeParty = [appState.playerSave.roster.activeHero, appState.playerSave.roster.activeCompanion]
            .compactMap(\.artReference)
            .flatMap { reference in
                [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
            }
        let starterChoices: [String] =
            if appState.playerSave.starterSelection.phase == .complete {
                []
            } else {
                (GameContent.heroes + GameContent.companions)
                    .compactMap { $0.artReference?.thumbnailImageName }
            }
        let activeEnemy = appState.playerSave.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference(worldSeed: appState.playerSave.worldSeed)
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return Array(
            Set(activeParty + starterChoices + enemyNames + rootTabImageNames(for: appState)),
        ).sorted()
    }

    private static func rootTabImageNames(for appState: AppState) -> [String] {
        let roster = appState.playerSave.roster
        let inventory = appState.playerSave.inventory
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit

        let collectionCombatants = (
            Array(roster.collectionHeroes.prefix(shelfLimit))
                + Array(roster.collectionCompanions.prefix(shelfLimit)),
        ).compactMap { $0.artReference?.thumbnailImageName }
        let collectionDetail = CollectionView.imminentDetailArtworkNames(roster: roster)
        let collectionItems = CollectionItemCategory.allCases.flatMap { category in
            inventory.items.lazy.filter(category.contains).prefix(shelfLimit).compactMap {
                $0.artReference?.thumbnailImageName
            }
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
                ?? ArtCatalog.backgroundArtByID["chapter-1"],
        )?.imageName
        let campaignRows = chapter.stages.flatMap { stage -> [String] in
            if let combatant = stage.encounterCombatantArtReference(
                worldSeed: appState.playerSave.worldSeed,
            ) {
                return [combatant.imageName, combatant.thumbnailImageName].compactMap(\.self)
            }
            if let encounter = stage.encounterArtReference {
                return [encounter.imageName, encounter.thumbnailImageName].compactMap(\.self)
            }
            return []
        }

        return collectionCombatants
            + collectionDetail
            + collectionItems
            + playModeCards
            + homesteadCards
            + resourceIcons
            + campaignRows
            + [homesteadHero, campaignHero].compactMap(\.self)
    }
}

private struct PreparedAppRoot: View {
    @Environment(\.displayScale) private var displayScale
    private let artworkCache = PreparedArtworkCache.shared
    @State private var isResourcePreparationComplete = false
    @State private var isShellWarmupComplete = false
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
                HiddenTabPrewarm(appState: appState) {
                    didWarmHiddenTabs = true
                }
            }
            if !isPreparationComplete {
                LaunchWarmupView()
                    .allowsHitTesting(true)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        isMinimumLoadingTimeComplete = true
                    }
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
        .environment(appState.play.encounters)
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
            isShellWarmupComplete = true
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
            && isShellWarmupComplete
            && isMinimumLoadingTimeComplete
            && areCastEffectsPrepared
    }
}
