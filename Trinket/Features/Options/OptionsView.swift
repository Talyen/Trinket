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
            if let status = appState.shellDataStatusPresentation {
                Section("Progress Status") {
                    Label(status.message, systemImage: status.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(foregroundStyle(for: status.style))
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

    private func foregroundStyle(for style: ShellDataStatusPresentation.Style) -> AnyShapeStyle {
        switch style {
        case .destructive:
            AnyShapeStyle(TrinketDesign.Colors.destructive)
        case .secondary:
            AnyShapeStyle(.secondary)
        }
    }
}
