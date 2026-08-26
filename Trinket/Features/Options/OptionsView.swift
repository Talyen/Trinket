import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
#if DEBUG
import TrinketBattleFeature
#endif

struct OptionsView: View {
    @Environment(OptionsStore.self) private var optionsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var isResetConfirmationPresented = false
    @State private var actionErrorMessage: String?

    let persistenceStatusMessage: () -> String?
    let applyMusicVolumeLive: (Double, ScenePhase) -> Void
    let playToggleSFX: (Bool, Double) -> Void
    let resetGameplayProgress: () -> Bool
    let unlockAllContent: () -> Bool

    var body: some View {
        @Bindable var options = optionsStore

        Form {
            if let message = persistenceStatusMessage() {
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
                        applyMusicVolumeLive(volume, scenePhase)
                    }
                )

                VolumeOptionRow(
                    title: "Sound Effects",
                    value: $options.effectsVolume
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
                Picker("Show Animations", selection: $options.ultimateCinematicShowPolicy) {
                    ForEach(UltimateCinematicShowPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.showAnimationsPicker)

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
                    if !unlockAllContent() {
                        actionErrorMessage = "Couldn't unlock content. Try again."
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Options.unlockAllButton)
            } header: {
                Text("Developer")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.options)
        .alert(
            "Reset Game Progress?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Reset Game Progress", role: .destructive) {
                if !resetGameplayProgress() {
                    actionErrorMessage = "Couldn't reset progress. Try again."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes journey, roster, and inventory progress on this device. Settings are kept.")
        }
        .trinketFailureAlert("Action Failed", message: $actionErrorMessage)
    }
}
