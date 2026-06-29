import SwiftUI

struct OptionsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var options = appState.options

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $options.theme) {
                    ForEach(TrinketDesign.AppTheme.allCases) { themeOption in
                        Text(themeOption.rawValue).tag(themeOption)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Theme Picker")
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

            Section("About") {
                LabeledContent("Version", value: appVersionText)
                LabeledContent("Build", value: appBuildText)
            }
        }
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("Options Screen")
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
