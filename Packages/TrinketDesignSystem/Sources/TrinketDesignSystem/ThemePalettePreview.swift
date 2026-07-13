import SwiftUI

private struct ThemePaletteGallery: View {
    private let semanticColors: [(String, Color)] = [
        ("Antique Gold", TrinketDesign.Colors.accent),
        ("Highlight Gold", TrinketDesign.Colors.accentEmphasized),
        ("Pressed Gold", TrinketDesign.Colors.accentPressed),
        ("Success", TrinketDesign.Colors.success),
        ("Warning", TrinketDesign.Colors.warning),
        ("Destructive", TrinketDesign.Colors.destructive),
        ("Informational", TrinketDesign.Colors.informational),
        ("Arcane", TrinketDesign.Colors.arcane),
        ("Health", TrinketDesign.Colors.health),
        ("Health Restore", TrinketDesign.Colors.healthRestore)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraLargeSpacing) {
                typography
                surfaces
                artworkBlends
                colors
                controls
                materials
                solidFallbackReference
            }
            .padding(TrinketDesign.Metrics.contentMargin)
        }
        .trinketScreenBackground()
        .tint(TrinketDesign.Colors.accent)
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text("Trinket Theme")
                .trinketTypography(.screenDisplay)
            Text("System semantic text remains adaptive over the cool charcoal canvas.")
                .foregroundStyle(.secondary)
        }
    }

    private var surfaces: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            Text("Surfaces").trinketTypography(.sectionTitle)
            HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                previewSurface("Base", role: .base)
                previewSurface("Selected", role: .selected)
            }
            HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                previewSurface("Reward", role: .reward)
                previewSurface("Disabled", role: .disabled)
            }
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            Text("Semantic Colors").trinketTypography(.sectionTitle)
            LazyVGrid(columns: [.init(.adaptive(minimum: 130))]) {
                ForEach(semanticColors, id: \.0) { name, color in
                    HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                        Circle().fill(color).frame(width: 22, height: 22)
                        Text(name).font(.caption)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .trinketSurface(.secondary)
    }

    private var artworkBlends: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            Text("Artwork Blends").trinketTypography(.sectionTitle)
            HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                artworkBlendPreview("None", blend: .none)
                artworkBlendPreview("Perimeter", blend: .perimeter(into: .surface))
                artworkBlendPreview("Bottom", blend: .bottom(into: .canvas))
            }
        }
    }

    private func artworkBlendPreview(_ title: String, blend: ArtworkBlend) -> some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            LinearGradient(
                colors: [
                    TrinketDesign.Colors.accentEmphasized,
                    TrinketDesign.Colors.informational,
                    TrinketDesign.Colors.arcane
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .trinketArtworkBlend(blend)
            .clipShape(TrinketDesign.cardShape)

            Text(title)
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            Text("Controls").trinketTypography(.sectionTitle)
            HStack {
                Button("Primary") {}
                    .trinketPrimaryActionButton()
                Button("Disabled") {}
                    .trinketPrimaryActionButton()
                    .disabled(true)
            }
            Toggle("Native gold tint", isOn: .constant(true))
        }
    }

    private var materials: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            Text("Materials").trinketTypography(.sectionTitle)
            Text("Neutral utility glass")
                .padding()
                .frame(maxWidth: .infinity)
                .trinketMaterial(.bottomBar)
            Text("Gold is reserved for rewards")
                .padding()
                .frame(maxWidth: .infinity)
                .trinketMaterial(.rewardReveal)
        }
    }

    private var solidFallbackReference: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text("Reduce Transparency Fallback").trinketTypography(.sectionTitle)
            Text("Glass becomes a solid semantic panel with a visible boundary.")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(TrinketDesign.Colors.elevated, in: TrinketDesign.cardShape)
                .overlay {
                    TrinketDesign.cardShape.stroke(TrinketDesign.Colors.subtleStroke)
                }
        }
    }

    private func previewSurface(_ title: String, role: SurfaceRole) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, minHeight: 50)
            .trinketSurface(role)
    }
}

#Preview("Gold and Charcoal Palette") {
    ThemePaletteGallery()
        .preferredColorScheme(.dark)
}
