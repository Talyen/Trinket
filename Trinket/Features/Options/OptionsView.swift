import BattleEngine
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
            Section("Audio") {
                VolumeOptionRow(
                    title: "Music",
                    value: $options.musicVolume,
                    onLiveChange: { volume in
                        appState.applyMusicVolumeLive(volume, scenePhase: scenePhase)
                    },
                )

                VolumeOptionRow(
                    title: "Sound Effects",
                    value: $options.effectsVolume,
                    onLiveChange: { volume in
                        playToggleSFX(true, volume)
                    },
                )

                Toggle(isOn: $options.hapticsEnabled) {
                    Label {
                        Text("Haptics")
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

            Section("Battle") {
                if BattleFeatureFlags.ultimateCinematicAnimationsEnabled {
                    Picker("Ultimate Animations", selection: $options.ultimateCinematicShowPolicy) {
                        ForEach(UltimateCinematicShowPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Options.showAnimationsPicker)
                }

                Toggle(isOn: $options.rememberAutoBattlePreference) {
                    Label {
                        Text("Remember Auto-Battle Preference")
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
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.options)
        .disabled(appState.playerSave.isRetryingSaveAction)
    }

    private var purchaseSection: some View {
        Section("Full Game") {
            if fullGame.ownership.access.hasFullGame {
                Label(
                    fullGame.ownership == .familyShared ? "Shared with your family" : "Full Game · Purchased",
                    systemImage: "checkmark.circle",
                )
                .trinketTypography(.body)
            } else {
                Button("Unlock Full Game") { requestOffer(.options) }
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
                    Text("Restore Purchases")
                }
            }
            .trinketTypography(.body)
            .disabled(fullGame.isRestoring || fullGame.isPurchasing)
            .accessibilityIdentifier(AccessibilityID.FullGame.restore)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link("Support", destination: TrinketPublicPages.support)
                .trinketTypography(.body)
            Link("Privacy Policy", destination: TrinketPublicPages.privacy)
                .trinketTypography(.body)
        }
    }

    @MainActor
    @ViewBuilder
    private var gameDataSection: some View {
        Section("Game Data") {
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
                Button("Cancel") { isResetConfirmationPresented = false }
                    .accessibilityIdentifier(AccessibilityID.Options.resetProgressCancel)
                Button("Reset Game Progress", role: .destructive) {
                    guard isResetConfirmationPresented, !appState.playerSave.isRetryingSaveAction else { return }
                    isResetConfirmationPresented = false
                    if !appState.resetGameplayProgress() {
                        appState.playerSave.retrySaveAction(key: "reset-progress") {
                            _ = appState.resetGameplayProgress()
                        }
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.resetProgressConfirmation)
            } else {
                Button("Reset Game Progress", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .accessibilityIdentifier(AccessibilityID.Options.resetProgressButton)
            }
        }

        #if DEBUG
        Section {
            NavigationLink("Preview Lab") {
                PreviewLabView()
            }

            Button("Unlock All") {
                if !appState.unlockAllContent() {
                    appState.playerSave.retrySaveAction(key: "unlock-content") {
                        _ = appState.unlockAllContent()
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Options.unlockAllButton)
        } header: {
            Text("Developer")
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
