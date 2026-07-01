import SwiftUI

struct OptionsView: View {
    @Environment(AppState.self) private var appState
    @State private var isResetConfirmationPresented = false

    var body: some View {
        @Bindable var options = appState.options

        Form {
            Section("Appearance") {
                HStack {
                    Picker(selection: $options.theme) {
                        ForEach(TrinketDesign.AppTheme.allCases) { themeOption in
                            Text(themeOption.rawValue).tag(themeOption)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Theme")
                    .accessibilityIdentifier("Theme Picker")
                }
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
            }

            Section("Game Data") {
                Button("Reset Game Progress", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .accessibilityIdentifier("Reset Game Progress Button")
            }

            Section("iCloud") {
                LabeledContent("Progress Sync") {
                    if appState.syncCoordinator.status == .syncing {
                        ProgressView()
                            .accessibilityIdentifier("iCloud Sync Progress")
                    }
                }

                Text(appState.syncCoordinator.status.displayText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("iCloud Sync Status")

                Button("Sync Now") {
                    Task {
                        await appState.syncCoordinator.syncNow()
                    }
                }
                .accessibilityIdentifier("Sync Now Button")
            }

            Section("About") {
                LabeledContent("Version", value: appVersionText)
                LabeledContent("Build", value: appBuildText)
            }
        }
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("Options Screen")
        .alert(
            "Reset Game Progress?",
            isPresented: $isResetConfirmationPresented,
        ) {
            Button("Reset Game Progress", role: .destructive) {
                appState.resetGameplayProgress()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes journey, roster, and inventory progress on this device and iCloud. Settings are kept.")
        }
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
