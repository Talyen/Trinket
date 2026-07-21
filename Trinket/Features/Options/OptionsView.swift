import SwiftUI
import TrinketDesignSystem

struct OptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var isResetConfirmationPresented = false
    @State private var actionErrorMessage: String?
    var body: some View {
        @Bindable var options = appState.options

        Form {
            if let message = appState.persistenceStatusMessage {
                Section("Progress Status") {
                    Label(message, systemImage: "externaldrive.badge.exclamationmark")
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(TrinketDesign.Colors.destructive)
                        .accessibilityIdentifier("Progress Status Message")
                }
            }

            Section("Audio") {
                VolumeOptionRow(
                    title: "Music",
                    value: $options.musicVolume,
                    onLiveChange: { volume in
                        appState.applyMusicVolumeLive(volume, scenePhase: scenePhase)
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
                .accessibilityIdentifier("Haptics Toggle")
                .onChange(of: options.hapticsEnabled) { _, isEnabled in
                    appState.sfxPlayer.play(
                        isEnabled ? SFXID.uiToggleOn : SFXID.uiToggleOff,
                        volume: options.effectsVolume
                    )
                }
            }

            Section("Battle") {
                Picker("Show Animations", selection: $options.ultimateCinematicShowPolicy) {
                    ForEach(UltimateCinematicShowPolicy.pickerCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .accessibilityIdentifier("Show Animations Picker")
            }

            Section("Game Data") {
                Button("Reset Game Progress", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .accessibilityIdentifier("Reset Game Progress Button")
            }

            #if DEBUG
            Section {
                Button("Unlock All") {
                    if !appState.unlockAllContent() {
                        actionErrorMessage = "Couldn't unlock content. Try again."
                    }
                }
                .accessibilityIdentifier("Unlock All Button")
            } header: {
                Text("Developer")
            } footer: {
                Text("Unlock All is Debug-only. Launch with -enable-frame-metrics for the Simulator soak gate. Unlock All grants all heroes and companions at level 20 and clears Chapter 1.")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("Options Screen")
        .alert(
            "Reset Game Progress?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Reset Game Progress", role: .destructive) {
                if !appState.resetGameplayProgress() {
                    actionErrorMessage = "Couldn't reset progress. Try again."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes journey, roster, and inventory progress on this device. Settings are kept.")
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: {
                    if !$0 {
                        actionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }
}
