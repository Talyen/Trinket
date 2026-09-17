#if DEBUG
import SwiftUI

private struct DesignSystemGallery: View {
    @State private var actionsEnabled = true

    /// Curated, not exhaustive: token coverage is pinned by
    /// DesignTokenInvariantTests and the catalog tests, not by this gallery.
    private let semanticColors: [(String, Color)] = [
        ("Canvas", TrinketDesign.Colors.canvas),
        ("Surface", TrinketDesign.Colors.surface),
        ("Panel", TrinketDesign.Colors.panel),
        ("Elevated", TrinketDesign.Colors.elevated),
        ("Subtle Stroke", TrinketDesign.Colors.subtleStroke),
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
        ("Overlay Paper", TrinketDesign.Colors.Overlay.paper),
        ("Overlay Ink", TrinketDesign.Colors.Overlay.ink),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraLarge) {
                typography
                surfaces
                colors
                controls
                materials
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
                .trinketTypography(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var surfaces: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text("Surfaces").trinketTypography(.sectionTitle)
            HStack(spacing: TrinketDesign.Spacing.medium) {
                previewSurface("Secondary", role: .secondary)
                previewSurface("Dense Row", role: .denseRow)
            }
            previewSurface("Card", role: .card)
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
            Toggle("Actions Available", isOn: $actionsEnabled)
                .trinketTypography(.body)
            actionRow
                .disabled(!actionsEnabled)
            Text("Unavailable").trinketTypography(.caption)
            actionRow.disabled(true)
            Button("Inspect Selected Companion") {}
                .trinketTypography(.button)
                .trinketSecondaryActionButton()
                .disabled(!actionsEnabled)
        }
    }

    private var actionRow: some View {
        HStack(spacing: TrinketDesign.Spacing.medium) {
            Button("Build") {}
                .trinketTypography(.button)
                .trinketPrimaryActionButton()
            Button("Inspect") {}
                .trinketTypography(.button)
                .trinketSecondaryActionButton()
            Button("Close", systemImage: "xmark") {}
                .trinketIconButton()
        }
    }

    private var materials: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text("Materials").trinketTypography(.sectionTitle)
            previewMaterial("Bottom Bar", role: .bottomBar)
            previewMaterial("Homestead Footer", role: .homesteadFooter)
            previewMaterial("Subtle Overlay", role: .subtleOverlay)
            HStack(spacing: TrinketDesign.Spacing.medium) {
                Text("999,999 Gold")
                    .trinketTypography(.statValue)
                    .trinketGlassChip()
                Text("Selected")
                    .trinketTypography(.badge)
                    .trinketGlassChip(.emphasis)
            }
        }
    }

    private func previewMaterial(_ title: String, role: MaterialRole) -> some View {
        Text(title)
            .trinketTypography(.body)
            .padding()
            .frame(maxWidth: .infinity)
            .trinketMaterial(role)
    }

    private func previewSurface(_ title: String, role: SurfaceRole) -> some View {
        Text(title)
            .trinketTypography(.body)
            .frame(maxWidth: .infinity, minHeight: 50)
            .trinketSurface(role)
    }
}

#Preview("Compact iPhone", traits: .fixedLayout(width: 375, height: 812)) {
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}

#Preview("Compact iPhone Light", traits: .fixedLayout(width: 375, height: 812)) {
    DesignSystemGallery()
        .preferredColorScheme(.light)
}

#Preview("Wide iPhone", traits: .fixedLayout(width: 430, height: 932)) {
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}
#endif
