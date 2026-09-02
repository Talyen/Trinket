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

    init() {
        let environment = AppEnvironment.shared
        let makeBattleRuntime: (BattleRuntimeDependencies) -> any BattleRuntime = { dependencies in
            BattleSession(
                autoEndTurnDelay: environment.battleTickInterval ?? 0.4,
                presentationEnvironment: dependencies,
            )
        }

        do {
            let state = try AppState(
                environment: environment,
                makeBattleRuntime: makeBattleRuntime,
            )
            _appState = State(initialValue: state)
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)",
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let state = try AppState(
                    environment: environment,
                    playerSave: fallbackSave,
                    makeBattleRuntime: makeBattleRuntime,
                )
                _appState = State(initialValue: state)
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
                    priorityImageNames: priorityImageNames(for: appState),
                )
            } else {
                AppBootstrapFailureView(
                    message: bootstrapFailureMessage
                        ?? "Progress storage could not be started on this device.",
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

    private func rootTabImageNames(for appState: AppState) -> [String] {
        let roster = appState.playerSave.roster
        let inventory = appState.playerSave.inventory
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit

        let collectionCombatants = (
            Array(roster.collectionHeroes.prefix(shelfLimit))
                + Array(roster.collectionCompanions.prefix(shelfLimit)),
        ).compactMap { $0.artReference?.thumbnailImageName }
        let collectionDetail = CollectionView.imminentDetailArtworkNames(roster: roster)
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
    private static let minimumLaunchDisplayDuration: Duration = .seconds(1)

    @Environment(\.displayScale) private var displayScale
    @State private var artworkCache = PreparedArtworkCache.shared
    @State private var isResourcePreparationComplete = false
    @State private var isShellWarmupComplete = false
    @State private var areCastEffectsPrepared = false

    let appState: AppState
    let priorityImageNames: [String]

    private var battleSession: BattleSession {
        guard let session = appState.play.battle as? BattleSession else {
            preconditionFailure("AppState battle runtime must be BattleSession")
        }
        return session
    }

    private var shouldWarmHiddenTabs: Bool {
        appState.playerSave.starterSelection.phase == .complete && !isShellWarmupComplete
    }

    var body: some View {
        ZStack {
            if isResourcePreparationComplete {
                ContentView()
                    .environment(battleSession)
            }
            if shouldWarmHiddenTabs {
                HiddenTabPrewarm(appState: appState)
                    .environment(battleSession)
            }
            if !isPreparationComplete {
                LaunchWarmupView()
                    .allowsHitTesting(true)
                if shouldPrepareCastEffects, !areCastEffectsPrepared {
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
            await Task.yield()
            let displayedAt = ContinuousClock.now
            await BattlePresentationWarmup.prepareAndWait(displayScale: displayScale)
            await artworkCache.prepareAll(priorityImageNames: priorityImageNames)
            guard !Task.isCancelled else { return }
            if let stageID = appState.playerSave.journey.activeStageID,
               let stage = GameContent.stage(id: stageID) {
                appState.play.journey.prepareBattle(for: stage)
            }
            isResourcePreparationComplete = true
            if appState.playerSave.starterSelection.phase == .complete {
                let secondaryTabCount = max(0, AppTab.allCases.count - 1)
                await Task.yield()
                await Task.yield()
                try? await Task.sleep(for: ShellSession.tabFirstLayoutBudget)
                for _ in 0 ..< secondaryTabCount {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: ShellSession.secondaryTabFirstLayoutBudget)
                }
                await Task.yield()
            }
            let hold = Self.minimumLaunchDisplayDuration
                - displayedAt.duration(to: ContinuousClock.now)
            if hold > .zero {
                try? await Task.sleep(for: hold)
            }
            guard !Task.isCancelled else { return }
            isShellWarmupComplete = true
            await Task.yield()
            await Task.yield()
            artworkCache.reportMemorySnapshot(label: "interactiveRoot")
        }
    }

    private var shouldPrepareCastEffects: Bool {
        true
    }

    private var isPreparationComplete: Bool {
        isResourcePreparationComplete
            && isShellWarmupComplete
            && (areCastEffectsPrepared || !shouldPrepareCastEffects)
    }
}
