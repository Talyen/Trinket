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
    @Binding var stageMessage: StageMapMessage?
    @State private var preparedOverlayID: UUID?
    @State private var preparedBattleView: BattleView?

    var body: some View {
        let configuration = battle.overlayBattleConfiguration
        let isActive = battle.activeBattle != nil
        NavigationStack {
            Group {
                if let preparedBattleView {
                    preparedBattleView
                        .trinketPresentationVisibility(
                            isActive && preparedOverlayID == configuration?.id,
                            opacity: 1,
                        )
                        .id(preparedOverlayID)
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
        .trinketPresentationVisibility(
            isActive && preparedOverlayID == configuration?.id,
            opacity: isActive && preparedBattleView != nil ? 1 : 0,
        )
        .animation(nil, value: battle.activeBattle?.id)
        .task(id: battlePresentationTaskKey) {
            let key = battlePresentationTaskKey
            await battle.prepareBattlePresentationAssets(displayScale: displayScale)
            guard !Task.isCancelled, key == battlePresentationTaskKey else { return }
            guard let configuration = battle.overlayBattleConfiguration,
                  let presentationContext = battlePresentationContext(for: configuration) else {
                preparedBattleView = nil
                preparedOverlayID = nil
                return
            }
            // Keep the captured outgoing display mounted until its replacement is ready.
            preparedBattleView = BattleView(
                configuration: configuration,
                presentationContext: presentationContext,
                battleSession: battle,
                completeVictory: { [battle] summary in
                    battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true)
                },
                restartBattle: { [weak play, stageMessage = $stageMessage] in
                    if let message = play?.restartActiveBattle() {
                        stageMessage.wrappedValue = message
                    }
                },
                retreat: { [weak play] in
                    play?.endBattleReturningToOrigin()
                },
                performanceScenario: AppEnvironment.shared.battlePerformanceScenario,
            )
            preparedOverlayID = configuration.id
        }
        .disabled(play.playerSave.isRetryingSaveAction)
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
                },
            )
            .trinketMessageAlert($stageMessage)
    }
}

private struct PlayBattleOverlaySheetsModifier: ViewModifier {
    @Bindable var battle: BattleSession

    func body(content: Content) -> some View {
        content
            .modifier(CombatantDetailSheet(
                selection: $battle.overlayCombatantDetail,
                signpostDetail: { "enemyDetail=\($0.id)" },
                artworkNames: { detail in
                    CombatantDetailPane.artworkNames(
                        combatant: detail.combatant, loadout: detail.combatant.abilityLoadout,
                        equipmentLoadout: detail.equipmentLoadout, inventoryItems: detail.inventoryItems,
                    )
                },
                detailContent: { detail in
                    CombatantDetailPane(snapshot: detail)
                },
            ))
            .preparedArtworkSheet(item: $battle.overlayAbilityDetail, artworkNames: {
                [$0.artReference?.imageName, $0.artReference?.thumbnailImageName].compactMap(\.self)
            }, content: { ability in
                NavigationStack {
                    AbilityDetailView(ability: ability)
                        .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
                }
                .trinketDetailSheet()
            })
            .sheet(isPresented: $battle.isShowingBattleLog) {
                BattleLogSheet(entries: battle.logEntries)
                    .trinketSheetSurface()
                    .presentationDetents([.medium])
            }
    }
}
