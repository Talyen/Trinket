import SwiftUI
import TrinketDesignSystem
import TrinketPersistence

struct OptionsView: View {
    @Environment(AppState.self) private var appState
    @State private var isResetConfirmationPresented = false
    @State private var resetErrorMessage: String?

    var body: some View {
        @Bindable var options = appState.options
        let battleSession = appState.battle
        let isInActiveBattle = battleSession.activeBattle != nil
        let canRetreat = isInActiveBattle
            && !battleSession.isShowingVictory
            && !battleSession.isShowingDefeat

        Form {
            if let message = appState.persistenceStatusMessage {
                Section("Progress Status") {
                    Label(message, systemImage: "externaldrive.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(TrinketDesign.Colors.destructive)
                        .accessibilityIdentifier("Progress Status Message")
                }
            }

            Section("Appearance") {
                Picker("Mode", selection: $options.appearance) {
                    ForEach(TrinketDesign.AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Appearance Picker")
            }

            Section("Audio") {
                VolumeOptionRow(
                    title: "Music",
                    value: $options.musicVolume
                )

                VolumeOptionRow(
                    title: "Sound Effects",
                    value: $options.effectsVolume
                )

                Toggle(isOn: $options.hapticsEnabled) {
                    Label {
                        Text("Haptics")
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
                Picker("Skip Ultimate Animations", selection: $options.ultimateCinematicSkipPolicy) {
                    ForEach(UltimateCinematicSkipPolicy.pickerCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .accessibilityIdentifier("Ultimate Skip Policy Picker")

                if isInActiveBattle {
                    Button {
                        appState.presentCombatLogFromOptions()
                    } label: {
                        Label("Combat Log", systemImage: "list.bullet.rectangle")
                    }
                    .accessibilityIdentifier(AccessibilityID.Battle.combatLog)

                    if canRetreat {
                        Button(role: .destructive) {
                            appState.endBattleReturningToOrigin()
                        } label: {
                            Label("Retreat", systemImage: "figure.run")
                        }
                        .tint(TrinketDesign.Colors.destructive)
                        .accessibilityIdentifier(AccessibilityID.Battle.retreat)
                    }
                }
            }

            Section("Game Data") {
                Button("Reset Game Progress", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .accessibilityIdentifier("Reset Game Progress Button")
            }
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground(.denseList)
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
                    resetErrorMessage = "Couldn't reset progress. Try again."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes journey, roster, and inventory progress on this device. Settings are kept.")
        }
        .alert(
            "Reset Failed",
            isPresented: Binding(
                get: { resetErrorMessage != nil },
                set: { if !$0 { resetErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
        }
    }
}
