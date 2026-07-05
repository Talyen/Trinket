#if DEBUG
import SwiftUI
import TrinketDesignSystem

@Observable
final class VisualTuningStore {
    var isEnabled = false
    var mode: BackgroundMode = .standard
    var values = BackgroundTuningValues.defaultPreview

    func reset() {
        values = BackgroundTuningValues.defaultPreview
    }

    func apply(_ variant: VisualTuningVariant) {
        values = variant.values
    }
}

struct VisualTuningVariant: Identifiable {
    let id: Int
    let name: String
    let values: BackgroundTuningValues

    static let gallery: [VisualTuningVariant] = [
        VisualTuningVariant(
            id: 1,
            name: "Quiet Corner",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.055,
                mainGlowStartRadius: 56,
                mainGlowEndRadius: 720,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.025,
                elementGlowStartRadius: 72,
                elementGlowEndRadius: 620,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 2,
            name: "Panel Warmth",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.035,
                mainGlowStartRadius: 110,
                mainGlowEndRadius: 860,
                mainGlowAnchor: .top,
                elementGlowOpacity: 0.045,
                elementGlowStartRadius: 82,
                elementGlowEndRadius: 540,
                elementGlowAnchor: .bottom,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 3,
            name: "Center Veil",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.045,
                mainGlowStartRadius: 120,
                mainGlowEndRadius: 900,
                mainGlowAnchor: .center,
                elementGlowOpacity: 0.018,
                elementGlowStartRadius: 100,
                elementGlowEndRadius: 700,
                elementGlowAnchor: .topTrailing,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 4,
            name: "Low Lift",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.05,
                mainGlowStartRadius: 80,
                mainGlowEndRadius: 680,
                mainGlowAnchor: .bottom,
                elementGlowOpacity: 0.035,
                elementGlowStartRadius: 72,
                elementGlowEndRadius: 600,
                elementGlowAnchor: .topLeading,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 5,
            name: "Edge Light",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.04,
                mainGlowStartRadius: 96,
                mainGlowEndRadius: 760,
                mainGlowAnchor: .trailing,
                elementGlowOpacity: 0.03,
                elementGlowStartRadius: 96,
                elementGlowEndRadius: 760,
                elementGlowAnchor: .leading,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 6,
            name: "Battle Hush",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.075,
                mainGlowStartRadius: 52,
                mainGlowEndRadius: 580,
                mainGlowAnchor: .topLeading,
                elementGlowOpacity: 0.055,
                elementGlowStartRadius: 48,
                elementGlowEndRadius: 520,
                elementGlowAnchor: .bottomTrailing,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 7,
            name: "Air Wash",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.028,
                mainGlowStartRadius: 120,
                mainGlowEndRadius: 900,
                mainGlowAnchor: .top,
                elementGlowOpacity: 0.016,
                elementGlowStartRadius: 120,
                elementGlowEndRadius: 820,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0
            )
        ),
        VisualTuningVariant(
            id: 8,
            name: "Accent Pool",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.065,
                mainGlowStartRadius: 44,
                mainGlowEndRadius: 540,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.07,
                elementGlowStartRadius: 40,
                elementGlowEndRadius: 460,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0
            )
        )
    ]
}

struct DebugVisualTuningView: View {
    @Environment(\.trinketTheme) private var theme
    @Environment(VisualTuningStore.self) private var tuning

    private let columns = [
        GridItem(.adaptive(minimum: 145), spacing: 12)
    ]

    var body: some View {
        @Bindable var tuning = tuning

        Form {
            Section("Live") {
                Toggle("Enabled", isOn: $tuning.isEnabled)

                Picker("Mode", selection: $tuning.mode) {
                    ForEach(BackgroundMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Gradient") {
                SliderRow(
                    title: "Glow",
                    value: binding(\.mainGlowOpacity),
                    range: 0 ... 0.36,
                    format: .number.precision(.fractionLength(2))
                )
                SliderRow(
                    title: "Start",
                    value: binding(\.mainGlowStartRadius),
                    range: 0 ... 120,
                    format: .number.precision(.fractionLength(0))
                )
                SliderRow(
                    title: "End",
                    value: binding(\.mainGlowEndRadius),
                    range: 280 ... 900,
                    format: .number.precision(.fractionLength(0))
                )

                Picker("Anchor", selection: binding(\.mainGlowAnchor)) {
                    ForEach(BackgroundGradientAnchor.allCases) { anchor in
                        Text(anchor.displayName).tag(anchor)
                    }
                }
            }

            Section("Element Glow") {
                SliderRow(
                    title: "Glow",
                    value: binding(\.elementGlowOpacity),
                    range: 0 ... 0.24,
                    format: .number.precision(.fractionLength(2))
                )
                SliderRow(
                    title: "Start",
                    value: binding(\.elementGlowStartRadius),
                    range: 0 ... 120,
                    format: .number.precision(.fractionLength(0))
                )
                SliderRow(
                    title: "End",
                    value: binding(\.elementGlowEndRadius),
                    range: 280 ... 900,
                    format: .number.precision(.fractionLength(0))
                )

                Picker("Anchor", selection: binding(\.elementGlowAnchor)) {
                    ForEach(BackgroundGradientAnchor.allCases) { anchor in
                        Text(anchor.displayName).tag(anchor)
                    }
                }
            }

            Section("Texture") {
                SliderRow(
                    title: "Texture",
                    value: binding(\.textureOpacity),
                    range: 0 ... 0.12,
                    format: .number.precision(.fractionLength(3))
                )
            }

            Section("Variants") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(VisualTuningVariant.gallery) { variant in
                        Button {
                            tuning.apply(variant)
                        } label: {
                            VariantPreview(
                                variant: variant,
                                mode: tuning.mode,
                                isSelected: tuning.values == variant.values
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                Button("Reset") {
                    tuning.reset()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .trinketScreenBackground(.denseList)
        .navigationTitle("Visual Tuning")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<BackgroundTuningValues, Value>) -> Binding<Value> {
        Binding(
            get: { tuning.values[keyPath: keyPath] },
            set: { tuning.values[keyPath: keyPath] = $0 }
        )
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: FloatingPointFormatStyle<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: format)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}

private struct VariantPreview: View {
    @Environment(\.trinketTheme) private var theme

    let variant: VisualTuningVariant
    let mode: BackgroundMode
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TrinketScreenBackground(mode: mode, elementTint: theme.palette.accent)
                .environment(\.trinketBackgroundTuning, variant.values)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.palette.accent)
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.palette.panelSurface.opacity(0.82))
                        .frame(width: 52, height: 8)
                }

                Text(variant.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact, style: .continuous)
                .stroke(isSelected ? theme.palette.accent : theme.palette.subtleStroke, lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityLabel(variant.name)
    }
}
#endif
