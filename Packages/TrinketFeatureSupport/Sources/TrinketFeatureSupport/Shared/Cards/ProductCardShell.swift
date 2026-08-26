import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Shared 3:4 aspect ratio card layout shell for Item, Ability, Combatant, and Empty slot cards.
@MainActor
public struct ProductCardShell<Art: View, Label: View>: View {
    var isLocked: Bool = false
    var isSelected: Bool = false
    var appliesCardSurface: Bool = true
    var showsLabel: Bool = true
    var reservesLabelSpace: Bool = true
    var shineKeywords: [Keyword]?
    /// Color-driven shine used when no keyword shine applies.
    var shineColors: [Color]?
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
        shineKeywords: [Keyword]? = nil,
        shineColors: [Color]? = nil,
        shineLineWidth: CGFloat = 2,
        accessibilityID: String? = nil,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder label: @escaping () -> Label = { EmptyView() }
    ) {
        self.isLocked = isLocked
        self.isSelected = isSelected
        self.appliesCardSurface = appliesCardSurface
        self.showsLabel = showsLabel
        self.reservesLabelSpace = reservesLabelSpace
        self.shineKeywords = shineKeywords
        self.shineColors = shineColors
        self.shineLineWidth = shineLineWidth
        self.accessibilityID = accessibilityID
        self.art = art
        self.label = label
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artTile

            if showsLabel {
                label()
                    .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                    .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
        .trinketAccessibilityIdentifier(accessibilityID)
    }

    private var borderShineColors: [Color]? {
        if let shineKeywords, !shineKeywords.isEmpty {
            return shineKeywords.map(\.visualStyle.color)
        }
        if let shineColors, !shineColors.isEmpty {
            return shineColors
        }
        return nil
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
            lineWidth: 1.5
        )
        .colorShineBorder(
            colors: borderShineColors,
            cornerRadius: TrinketDesign.Corners.card,
            lineWidth: shineLineWidth
        )
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
    }
}
