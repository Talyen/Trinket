import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

/// Mode hub + campaign/explore destinations. Does not observe battle overlays.
struct PlayBrowsingStack: View {
    @Environment(PlaySession.self) private var play
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail
    @Binding var navigationPath: [PlayLaunchDestination]
    @Binding var stageMessage: StageMapMessage?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PlayModeHubView(
                onOpenCampaign: { openMode(.campaign) },
                onOpenExplore: { openMode(.explore) }
            )
            .navigationDestination(for: PlayLaunchDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: PlayLaunchDestination) -> some View {
        switch destination {
        case .campaign:
            ChapterStageSelectView(
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:)
            )
        case .explore:
            ExploreHubView()
        case .spiresHub:
            SpiresHubView()
        case .labyrinthMap:
            LabyrinthMapView()
        case let .spireClimb(spireID):
            SpireClimbView(spireID: spireID)
        }
    }

    private func openMode(_ destination: PlayLaunchDestination) {
        guard !isBattleActive else { return }
        navigationPath.append(destination)
    }

    private func handleStageTap(_ stage: Stage) {
        if playerSave.journey.isActive(stage) {
            let interval = AppFramePacingSignposts.signposter.beginInterval(
                AppFramePacingSignposts.Name.stageSelectBattleActivate
            )
            defer {
                AppFramePacingSignposts.signposter.endInterval(
                    AppFramePacingSignposts.Name.stageSelectBattleActivate,
                    interval
                )
            }
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.stageSelectBattleActivate,
                detail: "stage=\(stage.id)"
            )
            if let message = journey.handleStagePrimaryAction(for: stage) {
                stageMessage = message
            }
        }
    }

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        presentPlayCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = journey.resolvedEncounter(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant
        )
    }
}

private struct BattlePresentationTaskKey: Equatable {
    let activeBattleID: UUID?
    let preparedRevision: Int
    let displayScale: CGFloat
}

/// Tracks only `activeBattle` so sheet/log writes do not rebuild Battle chrome identity.
struct PlayBattleOverlay: View {
    @Environment(PlaySession.self) private var play
    @Environment(BattleSession.self) private var battle
    @Environment(\.displayScale) private var displayScale
    @Binding var stageMessage: StageMapMessage?
    @State private var claimedVictoryHandlerOwnerID = UUID()
    @State private var didPresentLaunchVictory = false

    var body: some View {
        let configuration = battle.activeBattle
        // The stack itself is stable; activation inserts only prepared battle
        // content. Opacity crossfade softens enter/exit without a custom nav stack.
        NavigationStack {
            if let configuration {
                if let presentationContext = battlePresentationContext(for: configuration) {
                    BattleView(
                        configuration: configuration,
                        presentationContext: presentationContext,
                        battleSession: battle,
                        completeVictory: { summary in
                            completeVictory(
                                configuration: configuration,
                                summary: summary
                            )
                        },
                        restartBattle: { [weak play] in
                            play?.restartActiveBattle()
                        },
                        retreat: { [weak play] in
                            play?.endBattleReturningToOrigin()
                        },
                        performanceScenario: AppEnvironment.shared.battlePerformanceScenario
                    )
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .opacity(configuration == nil ? 0 : 1)
        .animation(TrinketMotion.Screen.crossfade, value: configuration?.id)
        .allowsHitTesting(configuration.flatMap { battlePresentationContext(for: $0) } != nil)
        .accessibilityHidden(configuration == nil)
        .onAppear(perform: installClaimedVictoryHandler)
        .onDisappear {
            battle.uninstallClaimedVictoryHandler(ownerID: claimedVictoryHandlerOwnerID)
        }
        .onChange(of: configuration?.id, initial: true) { _, _ in
            syncPresentationContext()
        }
        .task(id: battlePresentationTaskKey) {
            await battle.prepareBattlePresentationAssets(displayScale: displayScale)
        }
    }

    private var battlePresentationTaskKey: BattlePresentationTaskKey {
        BattlePresentationTaskKey(
            activeBattleID: battle.activeBattle?.id,
            preparedRevision: battle.preparedBattlePresentationRevision,
            displayScale: displayScale
        )
    }

    private func syncPresentationContext() {
        guard let configuration = battle.activeBattle,
              let presentationContext = battlePresentationContext(for: configuration)
        else { return }
        let launchVictoryWasPresented = battle.spectacle.isShowingVictory
        battle.installPresentationContext(presentationContext)
        if launchVictoryWasPresented {
            battle.presentLaunchVictory()
            didPresentLaunchVictory = true
            return
        }
        guard AppEnvironment.shared.launchScreen == .battleVictory,
              !didPresentLaunchVictory
        else { return }
        battle.presentLaunchVictory()
        didPresentLaunchVictory = true
    }

    private func battlePresentationContext(
        for configuration: BattleRunConfiguration
    ) -> BattlePresentationContext? {
        guard let runKey = configuration.runKey else { return .empty }
        return play.battlePresentation(for: runKey)
    }

    private func installClaimedVictoryHandler() {
        let failureMessage = $stageMessage
        battle.installClaimedVictoryHandler(
            ownerID: claimedVictoryHandlerOwnerID
        ) { [weak play, weak battle] configuration, earnedGold in
            guard let play, let battle else { return }
            let didPersist = play.completeActiveBattle(
                configuration,
                battleEarnedGold: earnedGold
            )
            if !didPersist {
                battle.presentVictoryChromeForPersistRetry()
                failureMessage.wrappedValue = Self.persistenceFailureMessage
            }
        }
    }

    private func completeVictory(
        configuration: BattleRunConfiguration,
        summary: BattleVictorySummary
    ) -> Bool {
        let didPersist = play.completeActiveBattle(
            configuration,
            battleEarnedGold: summary.rawBattleEarnedGold,
            materialRewards: summary.materialRewards
        )
        if !didPersist {
            stageMessage = Self.persistenceFailureMessage
        }
        return didPersist
    }

    private static let persistenceFailureMessage = StageMapMessage(
        title: "Couldn't Save Progress",
        message: "Your victory was not saved. Stay on this screen and try Continue again."
    )
}

/// Battle/session sheets and covers — isolated `@Bindable` so overlay writes stay here.
struct PlaySessionPresentationModifier: ViewModifier {
    @Environment(BattleSession.self) private var battle
    @Environment(PlaySession.self) private var play
    @Binding var stageMessage: StageMapMessage?

    func body(content: Content) -> some View {
        content
            .modifier(PlayBattleOverlaySheetsModifier(battle: battle))
            .modifier(PlayEncounterCoversModifier())
            .fullScreenCover(
                isPresented: Binding(
                    get: { play.currentPostBattleTalentCombatantID != nil },
                    set: { isPresented in
                        if !isPresented {
                            play.dismissPostBattleTalentChoice()
                        }
                    }
                )
            ) {
                PostBattleTalentChoiceView()
            }
            .trinketMessageAlert($stageMessage)
    }
}

private struct PlayBattleOverlaySheetsModifier: ViewModifier {
    @Bindable var battle: BattleSession

    func body(content: Content) -> some View {
        content
            .sheet(item: $battle.overlayCombatantDetail, content: { detail in
                NavigationStack {
                    CombatantDetailPane(snapshot: detail)
                }
                .trinketDetailSheet()
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "enemyDetail=\(detail.id)"
                    )
                }
            })
            .sheet(item: $battle.overlayAbilityDetail, content: { ability in
                NavigationStack {
                    AbilityDetailView(ability: ability)
                        .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
                }
                .trinketDetailSheet()
            })
            .sheet(isPresented: $battle.isShowingBattleLog) {
                BattleLogSheet(entries: battle.logEntries)
                    .presentationDetents([.medium])
            }
    }
}

private struct PlayEncounterCoversModifier: ViewModifier {
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(LabyrinthPlayMode.self) private var labyrinth

    func body(content: Content) -> some View {
        @Bindable var encounters = encounters
        @Bindable var labyrinth = labyrinth

        content
            .fullScreenCover(item: $encounters.activeMysteryEncounter) { session in
                MysteryEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(item: $encounters.activeShopEncounter) { session in
                ShopEncounterView(
                    session: session,
                    onLeave: {
                        _ = encounters.finishActiveShopEncounter()
                    }
                )
                .interactiveDismissDisabled()
            }
            .fullScreenCover(item: $labyrinth.activeNodeSession) { session in
                LabyrinthCampfireView(session: session)
            }
    }
}
