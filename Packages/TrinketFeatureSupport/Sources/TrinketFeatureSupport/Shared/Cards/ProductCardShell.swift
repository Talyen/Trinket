import SwiftUI
import TrinketDesignSystem

/// Shared 3:4 aspect ratio card layout shell for Item, Ability, Combatant, and Empty slot cards.
@MainActor
struct ProductCardShell<Art: View, Label: View>: View {
    var isLocked: Bool = false
    var lockedText: String? = "Locked"
    var isSelected: Bool = false
    var appliesCardSurface: Bool = true
    var showsLabel: Bool = true
    var reservesLabelSpace: Bool = true
    var accessibilityID: String?
    @ViewBuilder let art: () -> Art
    @ViewBuilder let label: () -> Label

    init(
        isLocked: Bool = false,
        lockedText: String? = "Locked",
        isSelected: Bool = false,
        appliesCardSurface: Bool = true,
        showsLabel: Bool = true,
        reservesLabelSpace: Bool = true,
        accessibilityID: String? = nil,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder label: @escaping () -> Label = { EmptyView() }
    ) {
        self.isLocked = isLocked
        self.lockedText = lockedText ?? "Locked"
        self.isSelected = isSelected
        self.appliesCardSurface = appliesCardSurface
        self.showsLabel = showsLabel
        self.reservesLabelSpace = reservesLabelSpace
        self.accessibilityID = accessibilityID
        self.art = art
        self.label = label
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artTile

            if showsLabel {
                label()
                    .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                    .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
        .optionalAccessibilityIdentifier(accessibilityID)
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
            .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? lockedText : nil)

        Group {
            if appliesCardSurface {
                baseTile
                    .trinketCardSurface()
                    .trinketArtworkPickerSelectionBorder(
                        isSelected: isSelected,
                        lineWidth: 1.5
                    )
            } else {
                baseTile
                    .clipShape(TrinketDesign.cardShape)
                    .trinketArtworkPickerSelectionBorder(
                        isSelected: isSelected,
                        lineWidth: 1.5
                    )
            }
        }
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ id: String?) -> some View {
        if let id {
            accessibilityIdentifier(id)
        } else {
            self
        }
    }
}
