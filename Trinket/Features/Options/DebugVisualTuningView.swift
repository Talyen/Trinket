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
            name: "Tonal Calm",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.012,
                surfaceWashOpacity: 0.080,
                bandOpacity: 0.025,
                bandHeight: 96,
                bandSpacing: 280,
                lineOpacity: 0.012,
                lineSpacing: 22,
                lineAngleDegrees: -8,
                textureOpacity: 0.010
            )
        ),
        VisualTuningVariant(
            id: 2,
            name: "Vellum",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.020,
                surfaceWashOpacity: 0.130,
                bandOpacity: 0.000,
                bandHeight: 120,
                bandSpacing: 260,
                lineOpacity: 0.018,
                lineSpacing: 16,
                lineAngleDegrees: 0,
                textureOpacity: 0.022
            )
        ),
        VisualTuningVariant(
            id: 3,
            name: "Ledger",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.008,
                surfaceWashOpacity: 0.055,
                bandOpacity: 0.060,
                bandHeight: 58,
                bandSpacing: 118,
                lineOpacity: 0.020,
                lineSpacing: 24,
                lineAngleDegrees: 0,
                textureOpacity: 0.006
            )
        ),
        VisualTuningVariant(
            id: 4,
            name: "Slate Inset",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.000,
                surfaceWashOpacity: 0.035,
                bandOpacity: 0.035,
                bandHeight: 160,
                bandSpacing: 210,
                lineOpacity: 0.030,
                lineSpacing: 30,
                lineAngleDegrees: -18,
                textureOpacity: 0.000
            )
        ),
        VisualTuningVariant(
            id: 5,
            name: "Table Grain",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.018,
                surfaceWashOpacity: 0.040,
                bandOpacity: 0.020,
                bandHeight: 72,
                bandSpacing: 188,
                lineOpacity: 0.038,
                lineSpacing: 13,
                lineAngleDegrees: -5,
                textureOpacity: 0.026
            )
        ),
        VisualTuningVariant(
            id: 6,
            name: "Runic Paper",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.026,
                surfaceWashOpacity: 0.110,
                bandOpacity: 0.030,
                bandHeight: 104,
                bandSpacing: 170,
                lineOpacity: 0.026,
                lineSpacing: 19,
                lineAngleDegrees: 24,
                textureOpacity: 0.018
            )
        ),
        VisualTuningVariant(
            id: 7,
            name: "Native Plain",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.000,
                surfaceWashOpacity: 0.070,
                bandOpacity: 0.000,
                bandHeight: 96,
                bandSpacing: 240,
                lineOpacity: 0.000,
                lineSpacing: 18,
                lineAngleDegrees: 0,
                textureOpacity: 0.000
            )
        ),
        VisualTuningVariant(
            id: 8,
            name: "Map Bands",
            values: BackgroundTuningValues(
                accentWashOpacity: 0.014,
                surfaceWashOpacity: 0.060,
                bandOpacity: 0.075,
                bandHeight: 148,
                bandSpacing: 92,
                lineOpacity: 0.010,
                lineSpacing: 28,
                lineAngleDegrees: -12,
                textureOpacity: 0.000
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

            Section("Tonal Wash") {
                SliderRow(
                    title: "Accent",
                    value: binding(\.accentWashOpacity),
                    range: 0 ... 0.06,
                    format: .number.precision(.fractionLength(3))
                )
                SliderRow(
                    title: "Surface",
                    value: binding(\.surfaceWashOpacity),
                    range: 0 ... 0.18,
                    format: .number.precision(.fractionLength(3))
                )
            }

            Section("Bands") {
                SliderRow(
                    title: "Opacity",
                    value: binding(\.bandOpacity),
                    range: 0 ... 0.10,
                    format: .number.precision(.fractionLength(3))
                )
                SliderRow(
                    title: "Height",
                    value: binding(\.bandHeight),
                    range: 24 ... 220,
                    format: .number.precision(.fractionLength(0))
                )
                SliderRow(
                    title: "Spacing",
                    value: binding(\.bandSpacing),
                    range: 32 ... 320,
                    format: .number.precision(.fractionLength(0))
                )
            }

            Section("Linework") {
                SliderRow(
                    title: "Opacity",
                    value: binding(\.lineOpacity),
                    range: 0 ... 0.06,
                    format: .number.precision(.fractionLength(3))
                )
                SliderRow(
                    title: "Spacing",
                    value: binding(\.lineSpacing),
                    range: 8 ... 40,
                    format: .number.precision(.fractionLength(0))
                )
                SliderRow(
                    title: "Angle",
                    value: binding(\.lineAngleDegrees),
                    range: -35 ... 35,
                    format: .number.precision(.fractionLength(0))
                )
                SliderRow(
                    title: "Texture",
                    value: binding(\.textureOpacity),
                    range: 0 ... 0.05,
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
