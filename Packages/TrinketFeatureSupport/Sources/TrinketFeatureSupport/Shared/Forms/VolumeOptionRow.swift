import SwiftUI
import TrinketDesignSystem

public struct VolumeOptionRow: View {
    public enum Kind: Sendable {
        case soundEffects
        case music
    }

    let title: String
    let kind: Kind
    @Binding var value: Double
    var onLiveChange: ((Double) -> Void)?

    @State private var draft: Double
    @State private var isEditing = false

    private var percentageText: String {
        "\(Int((draft * 100).rounded()))%"
    }

    private var dynamicIconName: String {
        switch kind {
        case .music:
            draft == 0 ? "music.note.slash" : "music.note"
        case .soundEffects:
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

    public init(
        title: String,
        kind: Kind = .soundEffects,
        value: Binding<Double>,
        onLiveChange: ((Double) -> Void)? = nil,
    ) {
        self.title = title
        self.kind = kind
        _value = value
        self.onLiveChange = onLiveChange
        _draft = State(initialValue: value.wrappedValue)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            HStack {
                Label {
                    Text(balanced: title)
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
                },
            )
            .accessibilityLabel(title)
            .accessibilityValue(percentageText)
            .onChange(of: draft) { _, newValue in
                if isEditing {
                    onLiveChange?(newValue)
                } else if value != newValue {
                    // Native non-drag adjustments have no drag-end commit.
                    value = newValue
                    onLiveChange?(newValue)
                }
            }
        }
        .accessibilityIdentifier("\(title) Volume")
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                draft = value
            }
        }
        .onChange(of: value) { _, newValue in
            guard !isEditing else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                draft = newValue
            }
        }
    }
}
