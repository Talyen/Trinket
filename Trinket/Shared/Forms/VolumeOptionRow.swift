import SwiftUI
import TrinketDesignSystem

struct VolumeOptionRow: View {
    let title: String
    @Binding var value: Double

    private var percentageText: String {
        "\(Int((value * 100).rounded()))%"
    }

    private var dynamicIconName: String {
        if title == "Music" {
            value == 0 ? "music.note.slash" : "music.note"
        } else {
            if value == 0 {
                "speaker.slash.fill"
            } else if value < 0.33 {
                "speaker.wave.1.fill"
            } else if value < 0.66 {
                "speaker.wave.2.fill"
            } else {
                "speaker.wave.3.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
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
        }
        .accessibilityIdentifier("\(title) Volume")
    }
}
