import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
#if DEBUG
import TrinketBattleFeature
#endif

struct OptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(FullGameStore.self) private var fullGame
    @Environment(\.requestFullGameOffer) private var requestOffer
    @Environment(OptionsStore.self) private var optionsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var isResetConfirmationPresented = false

    var body: some View {
        @Bindable var options = optionsStore

        Form {
            Section(String(localized: L10n.ui_optionsview_audio_bc1b8)) {
                VolumeOptionRow(
                    title: String(localized: L10n.ui_optionsview_music_6eb00),
                    value: $options.musicVolume,
                    onLiveChange: { volume in
                        appState.applyMusicVolumeLive(volume, scenePhase: scenePhase)
                    },
                )

                VolumeOptionRow(
                    title: String(localized: L10n.ui_optionsview_sound_effects_de7b5),
                    value: $options.effectsVolume,
                    onLiveChange: { volume in
                        playToggleSFX(true, volume)
                    },
                )

                Toggle(isOn: $options.hapticsEnabled) {
                    Label {
                        Text(L10n.ui_optionsview_haptics_fd470)
                            .trinketTypography(.body)
                    } icon: {
                        Image(systemName: options.hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.hapticsToggle)
                .onChange(of: options.hapticsEnabled) { _, isEnabled in
                    playToggleSFX(isEnabled, options.effectsVolume)
                }
            }

            Section(String(localized: L10n.ui_optionsview_battle_1b18e)) {
                Toggle(isOn: $options.rememberAutoBattlePreference) {
                    Label {
                        Text(L10n.ui_optionsview_remember_auto_battle_preference_c1275)
                            .trinketTypography(.body)
                    } icon: {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.rememberAutoBattleToggle)
                .onChange(of: options.rememberAutoBattlePreference) { _, isEnabled in
                    playToggleSFX(isEnabled, options.effectsVolume)
                }
            }

            purchaseSection
            aboutSection
            gameDataSection
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .navigationTitle(Text(L10n.ui_optionsview_options_d0db8))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.options)
        .disabled(appState.playerSave.isRetryingSaveAction)
    }

    private var purchaseSection: some View {
        Section(String(localized: L10n.ui_optionsview_full_game_59929)) {
            if fullGame.ownership.access.hasFullGame {
                Label(
                    fullGame
                        .ownership == .familyShared ? String(localized: L10n.ui_optionsview_shared_with_your_family_a9ba5) :
                        String(localized: L10n.ui_optionsview_full_game_purchased_08610),
                    systemImage: "checkmark.circle",
                )
                .trinketTypography(.body)
            } else {
                Button(String(localized: L10n.ui_optionsview_unlock_full_game_0108a)) { requestOffer(.options) }
                    .trinketTypography(.body)
                    .accessibilityIdentifier(AccessibilityID.FullGame.options)
            }
            Button {
                Task { await fullGame.restore() }
            } label: {
                HStack {
                    if fullGame.isRestoring {
                        ProgressView()
                    }
                    Text(L10n.ui_optionsview_restore_purchases_16351)
                }
            }
            .trinketTypography(.body)
            .disabled(fullGame.isRestoring || fullGame.isPurchasing)
            .accessibilityIdentifier(AccessibilityID.FullGame.restore)
            FullGameOutcomeMessage(outcome: fullGame.outcome)
        }
    }

    private var aboutSection: some View {
        Section(String(localized: L10n.ui_optionsview_about_4efca)) {
            Link(String(localized: L10n.ui_optionsview_support_be919), destination: TrinketPublicPages.support)
                .trinketTypography(.body)
            Link(String(localized: L10n.ui_optionsview_privacy_policy_506ff), destination: TrinketPublicPages.privacy)
                .trinketTypography(.body)
        }
    }

    @MainActor
    @ViewBuilder
    private var gameDataSection: some View {
        Section(String(localized: L10n.ui_optionsview_game_data_15041)) {
            if isResetConfirmationPresented {
                Text(
                    appState.playerSave.resetAffectsCloudProgress ? """
                    This permanently clears your game progress on this device and your synced devices when iCloud is available. \
                    You'll choose a new starter Hero again. Options settings and Full Game ownership are kept.
                    """ : """
                    This permanently clears your Campaign stages, Explore runs, Heroes and Companions, \
                    Items, and Homestead upgrades on this device. You'll choose a new starter Hero again. \
                    Options settings are kept.
                    """,
                )
                .trinketTypography(.secondaryBody)
                Button(String(localized: L10n.ui_optionsview_cancel_19766)) { isResetConfirmationPresented = false }
                    .accessibilityIdentifier(AccessibilityID.Options.resetProgressCancel)
                Button(String(localized: L10n.ui_optionsview_reset_game_progress_2edb2), role: .destructive) {
                    guard isResetConfirmationPresented, !appState.playerSave.isRetryingSaveAction else { return }
                    isResetConfirmationPresented = false
                    appState.playerSave.performSaveAction(key: "reset-progress") { _ in
                        _ = appState.resetGameplayProgress()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.resetProgressConfirmation)
            } else {
                Button(String(localized: L10n.ui_optionsview_reset_game_progress_2edb2), role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .accessibilityIdentifier(AccessibilityID.Options.resetProgressButton)
            }
        }

        #if DEBUG
        Section {
            NavigationLink(String(localized: L10n.ui_optionsview_game_feel_65589)) {
                GameFeelPreviewView(
                    stage: GameContent.chapters[0].stages.first { $0.encounter.isCombat } ?? GameContent.chapters[0].stages[0],
                    playSound: { appState.sfxPlayer.play($0, volume: optionsStore.effectsVolume) },
                )
            }
            .accessibilityIdentifier(AccessibilityID.GameFeel.entry)

            NavigationLink(String(localized: L10n.ui_optionsview_battle_transitions_fd4bd)) {
                BattleTransitionsPreviewView { stage in
                    BattleTransitionLabView(stage: stage) { enterBattle in
                        BattleTransitionsStagePicker(enterBattle: enterBattle)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.BattleTransitionLab.entry)

            Button(String(localized: L10n.ui_optionsview_unlock_all_59b3d)) {
                appState.playerSave.performSaveAction(key: "unlock-content") { _ in
                    _ = appState.unlockAllContent()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Options.unlockAllButton)
        } header: {
            Text(L10n.ui_optionsview_developer_3fb7b)
        }
        #endif
    }

    private func playToggleSFX(_ isEnabled: Bool, _ volume: Double) {
        appState.sfxPlayer.play(
            isEnabled ? SFXID.uiToggleOn : SFXID.uiToggleOff,
            volume: volume,
        )
    }
}
