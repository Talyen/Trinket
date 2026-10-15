#if DEBUG
import SwiftUI

private struct DesignSystemGallery: View {
    @State private var actionsEnabled = true

    /// Curated examples; asset availability and contrast have dedicated tests.
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
            Text(L10n.ui_designsystempreview_trinket_theme_73e54)
                .trinketTypography(.screenDisplay)
            Text(L10n.ui_designsystempreview_system_semantic_text_remains_adaptive_over_th_6d741)
                .trinketTypography(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var surfaces: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text(L10n.ui_designsystempreview_surfaces_fbb4d).trinketTypography(.sectionTitle)
            HStack(spacing: TrinketDesign.Spacing.medium) {
                previewSurface("Secondary", role: .secondary)
                previewSurface("Dense Row", role: .denseRow)
            }
            previewSurface("Card", role: .card)
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text(L10n.ui_designsystempreview_semantic_colors_1a188).trinketTypography(.sectionTitle)
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
            Text(L10n.ui_designsystempreview_controls_799c2).trinketTypography(.sectionTitle)
            Toggle(String(localized: L10n.ui_designsystempreview_actions_available_6d28e), isOn: $actionsEnabled)
                .trinketTypography(.body)
            actionRow
                .disabled(!actionsEnabled)
            Text(L10n.ui_designsystempreview_unavailable_ca184).trinketTypography(.caption)
            actionRow.disabled(true)
            Button(String(localized: L10n.ui_designsystempreview_inspect_selected_companion_62caa)) {}
                .trinketTypography(.button)
                .trinketSecondaryActionButton()
                .disabled(!actionsEnabled)
        }
    }

    private var actionRow: some View {
        HStack(spacing: TrinketDesign.Spacing.medium) {
            Button(String(localized: L10n.ui_designsystempreview_build_bdd25)) {}
                .trinketTypography(.button)
                .trinketPrimaryActionButton()
            Button(String(localized: L10n.ui_designsystempreview_inspect_e0723)) {}
                .trinketTypography(.button)
                .trinketSecondaryActionButton()
        }
    }

    private var materials: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text(L10n.ui_designsystempreview_materials_fd10a).trinketTypography(.sectionTitle)
            previewMaterial("Bottom Bar", role: .bottomBar)
            previewMaterial("Subtle Overlay", role: .subtleOverlay)
            HStack(spacing: TrinketDesign.Spacing.medium) {
                Text(L10n.ui_designsystempreview_999_999_gold_86147)
                    .trinketTypography(.statValue)
                    .trinketGlassChip()
                Text(L10n.ui_designsystempreview_selected_57fd7)
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
