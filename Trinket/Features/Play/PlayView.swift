import BattleEngine
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct PlayView: View {
    @Environment(PlaySession.self) private var play
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @State private var stageMessage: StageMapMessage?
    @State private var navigationPath: [PlayLaunchDestination] = []

    var body: some View {
        // Keep browsing chrome and battle overlay as separate observation scopes.
        // A single `@Bindable` BattleSession here rebuilt the campaign stack on every
        // overlay/sheet write (enemy detail, ability, log).
        ZStack {
            PlayBrowsingStack(
                navigationPath: $navigationPath,
                stageMessage: $stageMessage
            )
            PlayBattleOverlay()
        }
        .onAppear {
            restorePlayDestinationIfNeeded()
        }
        .onChange(of: play.shellSession.selectedTab) { previousTab, newTab in
            guard newTab == .play, previousTab != .play else { return }
            // A normal Play-tab visit is a fresh choice. Pending destinations
            // are consumed only for battle/deep-link restoration below.
            guard play.battle.activeBattle == nil else { return }
            restorePlayDestinationIfNeeded(resetForNormalEntry: true)
        }
        .onChange(of: play.battle.activeBattle?.id) { _, newID in
            if newID == nil {
                restorePlayDestinationIfNeeded()
            }
        }
        .modifier(PlaySessionPresentationModifier(stageMessage: $stageMessage))
    }

    /// Prefer pending post-battle / launch destinations. Otherwise leave the
    /// explicit path empty so the mode chooser is the Play root.
    private func restorePlayDestinationIfNeeded(resetForNormalEntry: Bool = false) {
        guard play.battle.activeBattle == nil else { return }

        if let destination = play.consumePendingDestination() {
            apply(destination)
            return
        }

        if resetForNormalEntry {
            navigationPath.removeAll()
        }
    }

    private func apply(_ destination: PlayLaunchDestination) {
        let path: [PlayLaunchDestination]
        switch destination {
        case .campaign:
            path = [.campaign]
        case .explore:
            path = [.explore]
        case .spiresHub:
            path = [.explore, .spiresHub]
        case .labyrinthMap:
            _ = labyrinth.enter()
            path = [.explore, .labyrinthMap]
        case let .spireClimb(spireID):
            path = [.explore, .spiresHub, .spireClimb(spireID)]
        }

        navigationPath = path
    }
}

/// Mode hub + campaign/explore destinations. Does not observe battle overlays.
private struct PlayBrowsingStack: View {
    @Environment(PlaySession.self) private var play
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
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
        guard battle.activeBattle == nil else { return }

        if destination == .campaign {
            // Front-load Stage Select battle prep on the mode-card press so the
            // NavigationStack push frame is mostly compositor work.
            prepareCampaignBattleResources()
        }
        navigationPath.append(destination)
    }

    private func prepareCampaignBattleResources() {
        if let stageID = playerSave.journey.activeStageID,
           let stage = GameContent.stage(id: stageID),
           stage.encounter.isCombat {
            journey.prepareBattle(for: stage)
        }
        Task { @MainActor in
            await BattlePresentationWarmup.prepareAndWait(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
            battle.prepareBattlePresentation(
                heroUltimateID: playerSave.roster.activeHero.abilityLoadout.ultimate?.id,
                companionUltimateID: playerSave.roster.activeCompanion.abilityLoadout.ultimate?.id
            )
            if let stageID = playerSave.journey.activeStageID {
                let names = battle.preparedAbilityArtworkNames(
                    for: PlayBattleOrigin.journey(stageID: stageID).runKey
                )
                await PreparedArtworkCache.shared.prepareAndPin(names: names)
            }
        }
    }

    private func handleStageTap(_ stage: Stage) {
        if playerSave.journey.isActive(stage) {
            play.noteMapScrollFocus(stage.id)
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
        battle.presentCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = journey.resolvedEncounter(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant,
            inventoryItems: playerSave.inventory.items
        )
    }
}

/// Tracks only `activeBattle` so sheet/log writes do not rebuild Battle chrome identity.
private struct PlayBattleOverlay: View {
    @Environment(PlaySession.self) private var play

    var body: some View {
        let configuration = play.battle.activeBattle
        // The stack itself is stable; activation inserts only prepared battle
        // content. Opacity crossfade softens enter/exit without a custom nav stack.
        NavigationStack {
            if let configuration {
                BattleView(
                    configuration: configuration,
                    battleSession: play.battle,
                    completeBattle: { [weak play] configuration, earnedGold, rewards in
                        play?.completeActiveBattle(
                            configuration,
                            battleEarnedGold: earnedGold,
                            materialRewards: rewards
                        ) ?? false
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
        }
        .opacity(configuration == nil ? 0 : 1)
        .animation(TrinketMotion.Screen.crossfade, value: configuration?.id)
        .allowsHitTesting(configuration != nil)
        .accessibilityHidden(configuration == nil)
    }
}

/// Battle/session sheets and covers — isolated `@Bindable` so overlay writes stay here.
private struct PlaySessionPresentationModifier: ViewModifier {
    @Environment(PlaySession.self) private var play
    @Binding var stageMessage: StageMapMessage?

    func body(content: Content) -> some View {
        @Bindable var battle = play.battle
        content
            .modifier(PlayBattleOverlaySheetsModifier(battle: battle))
            .modifier(PlayEncounterCoversModifier())
            .alert(item: $stageMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
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
                .trinketDetailSheet(dragIndicator: .hidden)
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
        content
            .fullScreenCover(
                item: dismissibleSessionBinding(
                    get: { encounters.activeMysteryEncounter },
                    dismissWithoutCompleting: { encounters.dismissActiveMysteryEncounterWithoutCompleting() }
                )
            ) { session in
                MysteryEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(
                item: dismissibleSessionBinding(
                    get: { encounters.activeShopEncounter },
                    dismissWithoutCompleting: { encounters.dismissActiveShopEncounterWithoutCompleting() }
                )
            ) { session in
                ShopEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .sheet(
                item: dismissibleSessionBinding(
                    get: { labyrinth.activeNodeSession },
                    dismissWithoutCompleting: { labyrinth.dismissActiveNodeSessionWithoutCompleting() }
                )
            ) { session in
                switch session.kind {
                case .rest:
                    LabyrinthRestView(session: session)
                case .craft:
                    LabyrinthCraftView(session: session)
                }
            }
    }

    /// Sheet/cover dismiss sets `nil`; route that through the incomplete-dismiss path
    /// instead of dropping the session without cleanup.
    private func dismissibleSessionBinding<Session>(
        get: @escaping () -> Session?,
        dismissWithoutCompleting: @escaping () -> Void
    ) -> Binding<Session?> {
        // Binding get/set are @Sendable; these closures only run on the MainActor UI path.
        let get = UncheckedSendableBox(get)
        let dismissWithoutCompleting = UncheckedSendableBox(dismissWithoutCompleting)
        return Binding(
            get: { get.value() },
            set: { newValue in
                if newValue == nil, get.value() != nil {
                    dismissWithoutCompleting.value()
                }
            }
        )
    }
}

/// Bridges MainActor UI closures into Binding's `@Sendable` get/set without requiring
/// session types to be `Sendable`.
///
/// Concurrency-Safety: `@unchecked Sendable` — the boxed closures capture
/// MainActor UI/session state and are only invoked from Binding get/set on the
/// MainActor presentation path; they are never called from a concurrent executor.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
