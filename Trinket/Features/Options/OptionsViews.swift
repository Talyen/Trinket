import SwiftUI

struct OptionsView: View {
    @AppStorage("options.musicVolume") private var musicVolume = 0.75
    @AppStorage("options.effectsVolume") private var effectsVolume = 0.85
    @AppStorage("options.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("options.theme") private var theme = TrinketDesign.AppTheme.system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
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
                    value: $musicVolume
                )

                VolumeOptionRow(
                    title: "Sound Effects",
                    value: $effectsVolume
                )

                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptics")
                    } icon: {
                        Image(systemName: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
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

struct VolumeOptionRow: View {
    let title: String
    @Binding var value: Double

    private var percentageText: String {
        "\(Int((value * 100).rounded()))%"
    }

    private var dynamicIconName: String {
        if title == "Music" {
            return value == 0 ? "music.note.slash" : "music.note"
        } else {
            if value == 0 {
                return "speaker.slash.fill"
            } else if value < 0.33 {
                return "speaker.wave.1.fill"
            } else if value < 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: dynamicIconName)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                Text(percentageText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: 0...1, step: 0.05)
                .accessibilityLabel(title)
                .accessibilityValue(percentageText)
        }
        .accessibilityIdentifier("\(title) Volume")
    }
}
