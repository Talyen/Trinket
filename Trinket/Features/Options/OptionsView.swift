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
    @State private var actionErrorMessage: String?
    @State private var actionErrorTrigger = 0

    var body: some View {
        @Bindable var options = optionsStore

        Form {
            if let message = appState.persistenceStatusMessage {
                Section("Progress Status") {
                    Label(message, systemImage: "externaldrive.badge.exclamationmark")
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(TrinketDesign.Colors.destructive)
                        .accessibilityIdentifier(AccessibilityID.Options.progressStatusMessage)
                }
            }

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
            gameDataSection
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.options)
        .alert(
            "Reset Game Progress?",
            isPresented: $isResetConfirmationPresented,
        ) {
            Button("Reset Game Progress", role: .destructive) {
                if !appState.resetGameplayProgress() {
                    actionErrorMessage = "Couldn't reset progress. Try again."
                    actionErrorTrigger &+= 1
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                """
                This permanently clears your Campaign stages, Explore runs, Heroes and Companions, \
                Items, and Homestead upgrades on this device. You'll choose a new starter Hero again. \
                Options settings are kept.
                """,
            )
        }
        .trinketFailureAlert("Action Failed", message: $actionErrorMessage)
        .trinketSensoryFeedback(
            .error,
            trigger: actionErrorTrigger,
            enabled: optionsStore.hapticsEnabled,
        )
    }

    private var purchaseSection: some View {
        Section("Full Game") {
            if fullGame.ownership.access.hasFullGame {
                Label(
                    fullGame.ownership == .familyShared ? "Shared with your family" : "Full Game purchased",
                    systemImage: "checkmark.circle",
                )
                .trinketTypography(.body)
            } else {
                Button("View Full Game") { requestOffer(.options) }
                    .trinketTypography(.body)
                    .accessibilityIdentifier(AccessibilityID.FullGame.options)
            }
            Button(fullGame.isRestoring ? "Restoring…" : "Restore Purchases") {
                Task { await fullGame.restore() }
            }
            .trinketTypography(.body)
            .disabled(fullGame.isRestoring || fullGame.isPurchasing)
            .accessibilityIdentifier(AccessibilityID.FullGame.restore)
            if let message = fullGame.message {
                Text(message)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.FullGame.status)
            }
            Link("Privacy", destination: TrinketPublicPages.privacy)
                .trinketTypography(.body)
            Link("Support", destination: TrinketPublicPages.support)
                .trinketTypography(.body)
        }
    }

    @ViewBuilder
    private var gameDataSection: some View {
        Section("Game Data") {
            Button("Reset Game Progress", role: .destructive) {
                isResetConfirmationPresented = true
            }
            .accessibilityIdentifier(AccessibilityID.Options.resetProgressButton)
        }

        #if DEBUG
        Section {
            NavigationLink("Preview Lab") {
                PreviewLabView()
            }

            Button("Unlock All") {
                if !appState.unlockAllContent() {
                    actionErrorMessage = "Couldn't unlock content. Try again."
                    actionErrorTrigger &+= 1
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
