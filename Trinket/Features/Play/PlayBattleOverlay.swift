import BattleEngine
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport

private struct BattlePresentationTaskKey: Equatable {
    let overlayConfigurationID: UUID?
    let preparedRevision: Int
    let displayScale: CGFloat
}

struct PlayBattleOverlay: View {
    @Environment(PlaySession.self) private var play
    @Environment(BattleSession.self) private var battle
    @Environment(\.displayScale) private var displayScale
    @Environment(OptionsStore.self) private var options
    @Binding var stageMessage: StageMapMessage?
    @State private var claimedVictoryHandlerOwnerID = UUID()
    @State private var didPresentLaunchVictory = false
    @State private var claimedVictoryErrorTrigger = 0

    var body: some View {
        let configuration = battle.overlayBattleConfiguration
        let isActive = battle.activeBattle != nil
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
                                summary: summary,
                            )
                        },
                        restartBattle: { [weak play] in
                            if let message = play?.restartActiveBattle() {
                                stageMessage = message
                            }
                        },
                        retreat: { [weak play] in
                            play?.endBattleReturningToOrigin()
                        },
                        performanceScenario: AppEnvironment.shared.battlePerformanceScenario,
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
        .opacity(isActive ? 1 : 0)
        .animation(TrinketMotion.Screen.crossfade, value: battle.activeBattle?.id)
        .allowsHitTesting(isActive && configuration.flatMap { battlePresentationContext(for: $0) } != nil)
        .accessibilityHidden(!isActive)
        .onAppear(perform: installClaimedVictoryHandler)
        .onDisappear {
            battle.uninstallClaimedVictoryHandler(ownerID: claimedVictoryHandlerOwnerID)
        }
        .onChange(of: configuration?.id, initial: true) { _, _ in
            syncPresentationContext()
        }
        .onChange(of: battle.activeBattle?.id) { _, _ in
            syncPresentationContext()
        }
        .task(id: battlePresentationTaskKey) {
            await battle.prepareBattlePresentationAssets(displayScale: displayScale)
        }
        .trinketSensoryFeedback(
            .error,
            trigger: claimedVictoryErrorTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: stageMessage) { _, newValue in
            if newValue?.message == Self.persistenceFailureMessage.message {
                claimedVictoryErrorTrigger &+= 1
            }
        }
    }

    private var battlePresentationTaskKey: BattlePresentationTaskKey {
        BattlePresentationTaskKey(
            overlayConfigurationID: battle.overlayBattleConfiguration?.id,
            preparedRevision: battle.preparedBattlePresentationRevision,
            displayScale: displayScale,
        )
    }

    private func syncPresentationContext() {
        guard let configuration = battle.overlayBattleConfiguration,
              let presentationContext = battlePresentationContext(for: configuration)
        else { return }
        let launchVictoryWasPresented = switch battle.spectacle.outcomePresentation {
        case .victory: true
        case .battle, .pendingVictory, .defeat: false
        }
        battle.installPresentationContext(presentationContext)
        guard battle.activeBattle != nil else { return }
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
        for configuration: BattleRunConfiguration,
    ) -> BattlePresentationContext? {
        guard let runKey = configuration.runKey else { return .empty }
        return play.battlePresentation(for: runKey)
    }

    private func installClaimedVictoryHandler() {
        let failureMessage = $stageMessage
        battle.installClaimedVictoryHandler(
            ownerID: claimedVictoryHandlerOwnerID,
        ) { [weak play, weak battle] configuration, earnedGold in
            guard let play, let battle else { return }
            let didPersist = play.completeActiveBattle(
                configuration,
                battleGold: earnedGold,
            )
            if !didPersist {
                battle.presentVictoryChromeForPersistRetry()
                failureMessage.wrappedValue = Self.persistenceFailureMessage
            }
        }
    }

    private func completeVictory(
        configuration: BattleRunConfiguration,
        summary: BattleVictorySummary,
    ) -> Bool {
        let didPersist = play.completeActiveBattle(
            configuration,
            battleGold: summary.goldFlow,
            materialRewards: summary.materialRewards,
        )
        if !didPersist {
            stageMessage = Self.persistenceFailureMessage
        }
        return didPersist
    }

    private static let persistenceFailureMessage = StageMapMessage(
        title: "Couldn't Save Progress",
        message: "Your victory was not saved. Stay on this screen and try Continue again.",
    )
}

struct PlaySessionPresentationModifier: ViewModifier {
    @Environment(BattleSession.self) private var battle
    @Environment(PlaySession.self) private var play
    @Binding var stageMessage: StageMapMessage?

    func body(content: Content) -> some View {
        content
            .modifier(PlayBattleOverlaySheetsModifier(battle: battle))
            .modifier(PlayEncounterCoversModifier())
            .sheet(
                isPresented: Binding(
                    get: { play.currentPostBattleTalentCombatantID != nil },
                    set: { isPresented in
                        if !isPresented {
                            play.dismissPostBattleTalentChoice()
                        }
                    },
                ),
                content: {
                    PostBattleTalentChoiceView()
                        .trinketDetailSheet()
                        .interactiveDismissDisabled()
                },
            )
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
                    isActive: true,
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "enemyDetail=\(detail.id)",
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

    func body(content: Content) -> some View {
        @Bindable var encounters = encounters

        content
            .fullScreenCover(item: $encounters.activeMysteryEncounter) { session in
                MysteryEncounterView(session: session)
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(item: $encounters.activeShopEncounter) { session in
                ShopEncounterView(
                    session: session,
                    onLeave: {
                        encounters.finishActiveShopEncounter()
                    },
                )
                .interactiveDismissDisabled()
            }
    }
}
