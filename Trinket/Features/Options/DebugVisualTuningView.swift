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
            name: "Warm Table",
            values: BackgroundTuningValues(
                tintHue: 0.08,
                tintSaturation: 0.70,
                tintBrightness: 0.44,
                tintOpacity: 0.24,
                accentWashOpacity: 0.030,
                surfaceWashOpacity: 0.090,
                bandOpacity: 0.040,
                bandHeight: 96,
                bandSpacing: 190,
                lineOpacity: 0.036,
                lineSpacing: 14,
                lineAngleDegrees: -6,
                textureOpacity: 0.028
            )
        ),
        VisualTuningVariant(
            id: 2,
            name: "Parchment",
            values: BackgroundTuningValues(
                tintHue: 0.13,
                tintSaturation: 0.58,
                tintBrightness: 0.82,
                tintOpacity: 0.34,
                accentWashOpacity: 0.018,
                surfaceWashOpacity: 0.180,
                bandOpacity: 0.020,
                bandHeight: 124,
                bandSpacing: 240,
                lineOpacity: 0.016,
                lineSpacing: 17,
                lineAngleDegrees: 2,
                textureOpacity: 0.034
            )
        ),
        VisualTuningVariant(
            id: 3,
            name: "Moon Slate",
            values: BackgroundTuningValues(
                tintHue: 0.60,
                tintSaturation: 0.52,
                tintBrightness: 0.48,
                tintOpacity: 0.28,
                accentWashOpacity: 0.010,
                surfaceWashOpacity: 0.060,
                bandOpacity: 0.065,
                bandHeight: 74,
                bandSpacing: 104,
                lineOpacity: 0.030,
                lineSpacing: 28,
                lineAngleDegrees: -20,
                textureOpacity: 0.006
            )
        ),
        VisualTuningVariant(
            id: 4,
            name: "Forest Ink",
            values: BackgroundTuningValues(
                tintHue: 0.33,
                tintSaturation: 0.68,
                tintBrightness: 0.34,
                tintOpacity: 0.30,
                accentWashOpacity: 0.020,
                surfaceWashOpacity: 0.040,
                bandOpacity: 0.050,
                bandHeight: 162,
                bandSpacing: 84,
                lineOpacity: 0.040,
                lineSpacing: 22,
                lineAngleDegrees: 18,
                textureOpacity: 0.018
            )
        ),
        VisualTuningVariant(
            id: 5,
            name: "Arcane Violet",
            values: BackgroundTuningValues(
                tintHue: 0.73,
                tintSaturation: 0.72,
                tintBrightness: 0.50,
                tintOpacity: 0.34,
                accentWashOpacity: 0.040,
                surfaceWashOpacity: 0.070,
                bandOpacity: 0.020,
                bandHeight: 70,
                bandSpacing: 220,
                lineOpacity: 0.050,
                lineSpacing: 16,
                lineAngleDegrees: -28,
                textureOpacity: 0.018
            )
        ),
        VisualTuningVariant(
            id: 6,
            name: "Ember Ledger",
            values: BackgroundTuningValues(
                tintHue: 0.02,
                tintSaturation: 0.80,
                tintBrightness: 0.48,
                tintOpacity: 0.30,
                accentWashOpacity: 0.050,
                surfaceWashOpacity: 0.120,
                bandOpacity: 0.090,
                bandHeight: 48,
                bandSpacing: 86,
                lineOpacity: 0.022,
                lineSpacing: 26,
                lineAngleDegrees: 0,
                textureOpacity: 0.010
            )
        ),
        VisualTuningVariant(
            id: 7,
            name: "Clean Native",
            values: BackgroundTuningValues(
                tintHue: 0.56,
                tintSaturation: 0.24,
                tintBrightness: 0.72,
                tintOpacity: 0.16,
                accentWashOpacity: 0.000,
                surfaceWashOpacity: 0.140,
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
            name: "Night Map",
            values: BackgroundTuningValues(
                tintHue: 0.66,
                tintSaturation: 0.78,
                tintBrightness: 0.28,
                tintOpacity: 0.36,
                accentWashOpacity: 0.018,
                surfaceWashOpacity: 0.030,
                bandOpacity: 0.100,
                bandHeight: 140,
                bandSpacing: 62,
                lineOpacity: 0.044,
                lineSpacing: 12,
                lineAngleDegrees: -12,
                textureOpacity: 0.024
            )
        )
    ]
}

struct DebugVisualTuningView: View {
    @Environment(\.trinketTheme) private var theme
    @Environment(VisualTuningStore.self) private var tuning
    @State private var previewVariant: VisualTuningVariant?

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
                    title: "Hue",
                    value: binding(\.tintHue),
                    range: 0 ... 1,
                    format: .number.precision(.fractionLength(2))
                )
                SliderRow(
                    title: "Saturation",
                    value: binding(\.tintSaturation),
                    range: 0 ... 1,
                    format: .number.precision(.fractionLength(2))
                )
                SliderRow(
                    title: "Brightness",
                    value: binding(\.tintBrightness),
                    range: 0 ... 1,
                    format: .number.precision(.fractionLength(2))
                )
                SliderRow(
                    title: "Tint",
                    value: binding(\.tintOpacity),
                    range: 0 ... 0.45,
                    format: .number.precision(.fractionLength(3))
                )
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
                            previewVariant = variant
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
        .fullScreenCover(item: $previewVariant) { variant in
            VariantFullScreenPreview(
                variant: variant,
                mode: tuning.mode
            )
        }
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

private struct VariantFullScreenPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trinketTheme) private var theme

    let variant: VisualTuningVariant
    let mode: BackgroundMode

    var body: some View {
        ZStack {
            TrinketScreenBackground(mode: mode, elementTint: theme.palette.accent)
                .environment(\.trinketBackgroundTuning, variant.values)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(variant.name)
                                .font(.largeTitle.weight(.bold))
                            Text(mode.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.semibold))
                                // UIStyleCheck: allow - Debug-only preview close control needs a stable tap target.
                                .frame(width: 38, height: 38)
                        }
                        // UIStyleCheck: allow - Debug-only modal close button uses native bordered chrome.
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Close Preview")
                    }

                    HStack(spacing: 10) {
                        PreviewPill(title: "Hue", value: variant.values.tintHue)
                        PreviewPill(title: "Tint", value: variant.values.tintOpacity)
                        PreviewPill(title: "Bands", value: variant.values.bandOpacity)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ], spacing: 14) {
                        PreviewSurface(title: "Collection", subtitle: "Hero loadout")
                        PreviewSurface(title: "Battle", subtitle: "Hit feedback")
                        PreviewSurface(title: "Reward", subtitle: "Rare item")
                        PreviewSurface(title: "Options", subtitle: "Dense list")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Open Field")
                            .font(.headline)

                        RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                            .fill(theme.palette.panelSurface.opacity(0.38))
                            .frame(height: 220)
                            .overlay(alignment: .bottomLeading) {
                                Text("Large empty areas reveal texture, bands, and color direction.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(14)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                                    .stroke(theme.palette.subtleStroke)
                            }
                    }
                }
                .padding(24)
                .padding(.top, 18)
            }
        }
    }
}

private struct PreviewPill: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .trinketSurface(.denseRow)
    }
}

private struct PreviewSurface: View {
    @Environment(\.trinketTheme) private var theme

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(theme.palette.accent)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(theme.palette.elevatedBackground.opacity(0.74))
                .frame(height: 68)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.palette.accent.opacity(0.42))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.palette.subtleStroke)
                    .frame(width: 42, height: 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .trinketSurface(.card)
    }
}
#endif
