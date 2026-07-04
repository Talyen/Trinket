import SwiftUI

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

            Slider(value: $value, in: 0 ... 1, step: 0.05)
                .accessibilityLabel(title)
                .accessibilityValue(percentageText)
        }
        .accessibilityIdentifier("\(title) Volume")
    }
}
