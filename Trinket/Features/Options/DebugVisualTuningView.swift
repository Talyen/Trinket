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
            name: "Soft Corner",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.12,
                mainGlowStartRadius: 18,
                mainGlowEndRadius: 620,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.08,
                elementGlowStartRadius: 24,
                elementGlowEndRadius: 500,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0.035
            )
        ),
        VisualTuningVariant(
            id: 2,
            name: "Deep Wash",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.20,
                mainGlowStartRadius: 8,
                mainGlowEndRadius: 560,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.10,
                elementGlowStartRadius: 18,
                elementGlowEndRadius: 420,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0.075
            )
        ),
        VisualTuningVariant(
            id: 3,
            name: "Centered Haze",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.15,
                mainGlowStartRadius: 40,
                mainGlowEndRadius: 700,
                mainGlowAnchor: .center,
                elementGlowOpacity: 0.06,
                elementGlowStartRadius: 28,
                elementGlowEndRadius: 460,
                elementGlowAnchor: .bottom,
                textureOpacity: 0.045
            )
        ),
        VisualTuningVariant(
            id: 4,
            name: "Low Ember",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.18,
                mainGlowStartRadius: 18,
                mainGlowEndRadius: 520,
                mainGlowAnchor: .bottomTrailing,
                elementGlowOpacity: 0.14,
                elementGlowStartRadius: 20,
                elementGlowEndRadius: 520,
                elementGlowAnchor: .topLeading,
                textureOpacity: 0.055
            )
        ),
        VisualTuningVariant(
            id: 5,
            name: "Airy",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.09,
                mainGlowStartRadius: 80,
                mainGlowEndRadius: 780,
                mainGlowAnchor: .top,
                elementGlowOpacity: 0.05,
                elementGlowStartRadius: 48,
                elementGlowEndRadius: 620,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0.02
            )
        ),
        VisualTuningVariant(
            id: 6,
            name: "Vignette",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.24,
                mainGlowStartRadius: 4,
                mainGlowEndRadius: 430,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.12,
                elementGlowStartRadius: 16,
                elementGlowEndRadius: 360,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0.09
            )
        ),
        VisualTuningVariant(
            id: 7,
            name: "Side Light",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.16,
                mainGlowStartRadius: 22,
                mainGlowEndRadius: 650,
                mainGlowAnchor: .trailing,
                elementGlowOpacity: 0.09,
                elementGlowStartRadius: 22,
                elementGlowEndRadius: 520,
                elementGlowAnchor: .leading,
                textureOpacity: 0.04
            )
        ),
        VisualTuningVariant(
            id: 8,
            name: "Bright Rune",
            values: BackgroundTuningValues(
                mainGlowOpacity: 0.28,
                mainGlowStartRadius: 10,
                mainGlowEndRadius: 500,
                mainGlowAnchor: .topTrailing,
                elementGlowOpacity: 0.18,
                elementGlowStartRadius: 16,
                elementGlowEndRadius: 440,
                elementGlowAnchor: .bottomLeading,
                textureOpacity: 0.065
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
