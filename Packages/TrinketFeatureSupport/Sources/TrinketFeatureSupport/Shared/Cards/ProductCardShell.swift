import SwiftUI
import TrinketDesignSystem

@MainActor
public struct ProductCardShell<Art: View, Label: View>: View {
    var isLocked: Bool = false
    var isSelected: Bool = false
    var appliesCardSurface: Bool = true
    var showsLabel: Bool = true
    var reservesLabelSpace: Bool = true
    var shine: Shine = .none
    var shineLineWidth: CGFloat = 2
    var accessibilityID: String?
    @ViewBuilder let art: () -> Art
    @ViewBuilder let label: () -> Label

    public init(
        isLocked: Bool = false,
        isSelected: Bool = false,
        appliesCardSurface: Bool = true,
        showsLabel: Bool = true,
        reservesLabelSpace: Bool = true,
        shine: Shine = .none,
        shineLineWidth: CGFloat = 2,
        accessibilityID: String? = nil,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder label: @escaping () -> Label = { EmptyView() },
    ) {
        self.isLocked = isLocked
        self.isSelected = isSelected
        self.appliesCardSurface = appliesCardSurface
        self.showsLabel = showsLabel
        self.reservesLabelSpace = reservesLabelSpace
        self.shine = shine
        self.shineLineWidth = shineLineWidth
        self.accessibilityID = accessibilityID
        self.art = art
        self.label = label
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            artTile

            if showsLabel {
                label()
                    .padding(.horizontal, TrinketDesign.Spacing.extraSmall)
                    .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
        .trinketAccessibilityIdentifier(accessibilityID)
    }

    @ViewBuilder
    private var artTile: some View {
        let baseTile = TrinketDesign.cardShape
            .fill(TrinketDesign.Colors.surface)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                art()
                    .clipShape(TrinketDesign.cardShape)
            }
            .trinketLockedCardEffect(isLocked: isLocked)

        Group {
            if appliesCardSurface {
                baseTile
                    .trinketCardSurface()
            } else {
                baseTile
                    .clipShape(TrinketDesign.cardShape)
            }
        }
        .trinketArtworkPickerSelectionBorder(
            isSelected: isSelected,
            lineWidth: 1.5,
        )
        .shineBorder(
            shine,
            cornerRadius: TrinketDesign.Corners.card,
            lineWidth: shineLineWidth,
        )
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
    }
}
