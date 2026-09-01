import SwiftUI

private struct DesignSystemGallery: View {
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
        ("Health Restore", TrinketDesign.Colors.healthRestore),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraLarge) {
                typography
                surfaces
                colors
                controls
                materials
                solidFallbackReference
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .trinketScreenBackground()
        .tint(TrinketDesign.Colors.accent)
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text("Trinket Theme")
                .trinketTypography(.screenDisplay)
            Text("System semantic text remains adaptive over the cool charcoal canvas.")
                .foregroundStyle(.secondary)
        }
    }

    private var surfaces: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text("Surfaces").trinketTypography(.sectionTitle)
            HStack(spacing: TrinketDesign.Spacing.medium) {
                previewSurface("Base", role: .base)
                previewSurface("Selected", role: .selected)
            }
            HStack(spacing: TrinketDesign.Spacing.medium) {
                previewSurface("Reward", role: .reward)
                previewSurface("Disabled", role: .disabled)
            }
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text("Semantic Colors").trinketTypography(.sectionTitle)
            LazyVGrid(columns: [.init(.adaptive(minimum: 130))]) {
                ForEach(semanticColors, id: \.0) { name, color in
                    HStack(spacing: TrinketDesign.Spacing.small) {
                        Circle().fill(color).frame(width: 22, height: 22)
                        Text(name).trinketTypography(.caption)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .trinketSurface(.secondary)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
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
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
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
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
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
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}
