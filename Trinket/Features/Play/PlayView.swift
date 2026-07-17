import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct PlayView: View {
    @Environment(AppState.self) private var appState
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
        .onChange(of: appState.selectedTab) { previousTab, newTab in
            guard newTab == .play, previousTab != .play else { return }
            // A normal Play-tab visit is a fresh choice. Pending destinations
            // are consumed only for battle/deep-link restoration below.
            guard appState.battle.activeBattle == nil else { return }
            restorePlayDestinationIfNeeded(resetForNormalEntry: true)
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newID in
            if newID == nil {
                restorePlayDestinationIfNeeded()
            }
        }
        .modifier(PlaySessionPresentationModifier(stageMessage: $stageMessage))
    }

    /// Prefer pending post-battle / launch destinations. Otherwise leave the
    /// explicit path empty so the mode chooser is the Play root.
    private func restorePlayDestinationIfNeeded(resetForNormalEntry: Bool = false) {
        guard appState.battle.activeBattle == nil else { return }

        if let destination = appState.consumePendingPlayDestination() {
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
        case .aspectsHub:
            path = [.explore, .aspectsHub]
        case .labyrinthMap:
            _ = appState.enterLabyrinth()
            path = [.explore, .labyrinthMap]
        case let .aspectClimb(aspectID):
            path = [.explore, .aspectsHub, .aspectClimb(aspectID)]
        }

        navigationPath = path
    }
}

/// Mode hub + campaign/explore destinations. Does not observe battle overlays.
private struct PlayBrowsingStack: View {
    @Environment(AppState.self) private var appState
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
        case .aspectsHub:
            AspectsHubView()
        case .labyrinthMap:
            LabyrinthMapView()
        case let .aspectClimb(aspectID):
            AspectClimbView(aspectID: aspectID)
        }
    }

    private func openMode(_ destination: PlayLaunchDestination) {
        guard appState.battle.activeBattle == nil else { return }

        if destination == .campaign {
            // Front-load Stage Select battle prep on the mode-card press so the
            // NavigationStack push frame is mostly compositor work.
            prepareCampaignBattleResources()
        }
        navigationPath.append(destination)
    }

    private func prepareCampaignBattleResources() {
        if let stageID = appState.journey.activeStageID,
           let stage = GameContent.stage(id: stageID),
           stage.encounter.battleEnemyID != nil {
            appState.prepareBattle(for: stage)
        }
        BattlePresentationWarmup.prepare(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        appState.battle.prepareBattlePresentation(
            heroUltimateID: appState.roster.activeHero.abilityLoadout.ultimate?.id,
            companionUltimateID: appState.roster.activeCompanion.abilityLoadout.ultimate?.id
        )
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.isActive(stage) {
            appState.noteMapScrollFocus(stage.id)
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
            if let message = appState.handleStagePrimaryAction(for: stage) {
                stageMessage = message
            }
        }
    }

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        appState.battle.presentCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant,
            inventoryState: appState.inventory
        )
    }
}

/// Tracks only `activeBattle` so sheet/log writes do not rebuild Battle chrome identity.
private struct PlayBattleOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let configuration = appState.battle.activeBattle
        // The stack itself is stable; activation inserts only prepared battle
        // content. No custom navigation controller or transition is involved.
        NavigationStack {
            if let configuration {
                BattleView(configuration: configuration)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .opacity(configuration == nil ? 0 : 1)
        .allowsHitTesting(configuration != nil)
        .accessibilityHidden(configuration == nil)
    }
}

/// Battle/session sheets and covers — isolated `@Bindable` so overlay writes stay here.
private struct PlaySessionPresentationModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var stageMessage: StageMapMessage?

    func body(content: Content) -> some View {
        @Bindable var battle = appState.battle
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
                CombatantDetailPane(snapshot: detail, hidesNavigationBar: true)
                    .trinketDetailSheet(dragIndicator: .hidden)
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
                BattleLogSheet(entries: battle.state?.log ?? [])
                    .presentationDetents([.medium])
            }
    }
}

private struct PlayEncounterCoversModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .fullScreenCover(
                item: dismissibleSessionBinding(
                    get: { appState.activeMysteryEncounter },
                    dismissWithoutCompleting: { appState.dismissActiveMysteryEncounterWithoutCompleting() }
                )
            ) { session in
                MysteryEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(
                item: dismissibleSessionBinding(
                    get: { appState.activeShopEncounter },
                    dismissWithoutCompleting: { appState.dismissActiveShopEncounterWithoutCompleting() }
                )
            ) { session in
                ShopEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .sheet(
                item: dismissibleSessionBinding(
                    get: { appState.activeLabyrinthNodeSession },
                    dismissWithoutCompleting: { appState.dismissActiveLabyrinthNodeSessionWithoutCompleting() }
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
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
