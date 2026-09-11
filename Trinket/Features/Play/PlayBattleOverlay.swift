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

    var body: some View {
        @Bindable var battle = battle
        let configuration = battle.overlayBattleConfiguration
        let isActive = battle.activeBattle != nil
        NavigationStack {
            Group {
                if let configuration {
                    if let presentationContext = battlePresentationContext(for: configuration) {
                        BattleView(
                            configuration: configuration,
                            presentationContext: presentationContext,
                            battleSession: battle,
                            completeVictory: { summary in
                                battle.claimVictory(configurationID: configuration.id, summary: summary)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarVisibility(.visible, for: .navigationBar)
        }
        .trinketPresentationVisibility(isActive)
        .animation(TrinketMotion.Screen.crossfade, value: battle.activeBattle?.id)
        .task(id: battlePresentationTaskKey) {
            await battle.prepareBattlePresentationAssets(displayScale: displayScale)
        }
        .trinketSensoryFeedback(
            .error,
            trigger: battle.completionError?.id,
            enabled: options.hapticsEnabled,
        )
        .trinketMessageAlert($battle.completionError)
    }

    private var battlePresentationTaskKey: BattlePresentationTaskKey {
        BattlePresentationTaskKey(
            overlayConfigurationID: battle.overlayBattleConfiguration?.id,
            preparedRevision: battle.preparedBattlePresentationRevision,
            displayScale: displayScale,
        )
    }

    private func battlePresentationContext(
        for configuration: BattleRunConfiguration,
    ) -> BattlePresentationContext? {
        play.battlePresentation(for: configuration)
    }
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
