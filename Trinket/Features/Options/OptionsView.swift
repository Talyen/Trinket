import SwiftUI
import TrinketDesignSystem
import TrinketPersistence

struct OptionsView: View {
    @Environment(AppState.self) private var appState
    @State private var isResetConfirmationPresented = false
    @State private var resetErrorMessage: String?

    var body: some View {
        @Bindable var options = appState.options

        Form {
            if let statusMessage = appState.shellDataStatusMessage {
                Section("Progress Status") {
                    Label(statusMessage, systemImage: statusSymbolName)
                        .font(.subheadline)
                        .foregroundStyle(statusForegroundStyle)
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
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("Options Screen")
        .onAppear {
            appState.refreshShellDataStatusMessage()
        }
        .alert(
            "Reset Game Progress?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Reset Game Progress", role: .destructive) {
                if !appState.resetGameplayProgress() {
                    resetErrorMessage = "Couldn't reset progress. Try again."
                } else {
                    appState.refreshShellDataStatusMessage()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes journey, roster, and inventory progress on this device and iCloud. Settings are kept.")
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

    private var statusSymbolName: String {
        if appState.playerSave.lastPersistenceError != nil {
            return "externaldrive.badge.exclamationmark"
        }

        switch appState.syncCoordinator.status {
        case .error, .iCloudUnavailable:
            return "icloud.slash"
        case .offline:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .upToDate:
            return "checkmark.icloud"
        case .idle:
            return "icloud"
        }
    }

    private var statusForegroundStyle: AnyShapeStyle {
        if appState.playerSave.lastPersistenceError != nil {
            return AnyShapeStyle(TrinketDesign.Colors.destructive)
        }

        switch appState.syncCoordinator.status {
        case .error, .iCloudUnavailable:
            return AnyShapeStyle(TrinketDesign.Colors.destructive)
        case .offline, .idle, .syncing:
            return AnyShapeStyle(.secondary)
        case .upToDate:
            return AnyShapeStyle(TrinketDesign.Colors.success)
        }
    }
}
