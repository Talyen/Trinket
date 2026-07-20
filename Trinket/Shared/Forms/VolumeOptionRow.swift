import SwiftUI
import TrinketDesignSystem

struct VolumeOptionRow: View {
    let title: String
    @Binding var value: Double
    var onLiveChange: ((Double) -> Void)?

    @State private var draft: Double = 0
    @State private var isEditing = false

    private var percentageText: String {
        "\(Int((draft * 100).rounded()))%"
    }

    private var dynamicIconName: String {
        if title == "Music" {
            draft == 0 ? "music.note.slash" : "music.note"
        } else {
            if draft == 0 {
                "speaker.slash.fill"
            } else if draft < 0.33 {
                "speaker.wave.1.fill"
            } else if draft < 0.66 {
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
                        .trinketTypography(.body)
                } icon: {
                    Image(systemName: dynamicIconName)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                Text(percentageText)
                    .trinketTypography(.statValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: $draft,
                in: 0 ... 1,
                step: 0.05,
                onEditingChanged: { editing in
                    if editing {
                        isEditing = true
                    } else {
                        isEditing = false
                        value = draft
                    }
                }
            )
            .onChange(of: draft) { _, newValue in
                guard isEditing else { return }
                onLiveChange?(newValue)
            }
        }
        .accessibilityIdentifier("\(title) Volume")
        .onAppear {
            draft = value
        }
        .onChange(of: value) { _, newValue in
            guard !isEditing else { return }
            draft = newValue
        }
    }
}
