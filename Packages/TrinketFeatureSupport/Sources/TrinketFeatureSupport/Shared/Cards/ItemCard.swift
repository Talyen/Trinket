import SwiftUI
import TrinketContent
import TrinketDesignSystem

public enum ItemCardPresentation {
    case standard
    case reveal
}

public struct ItemCard<Art: View>: View {
    @Environment(\.locale) private var locale
    let item: InventoryItem
    var showsAffixCount: Bool
    var isLocked = false
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var presentation: ItemCardPresentation = .standard
    var appliesCardSurface: Bool = true
    var isSelected = false
    var shine: Shine?
    var shineLineWidth: CGFloat = 2
    @ViewBuilder private var art: (InventoryItem) -> Art

    public init(
        item: InventoryItem,
        showsAffixCount: Bool,
        isLocked: Bool = false,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        presentation: ItemCardPresentation = .standard,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false,
        shine: Shine? = nil,
        shineLineWidth: CGFloat = 2,
        @ViewBuilder art: @escaping (InventoryItem) -> Art = { ItemArtwork(item: $0, variant: .thumbnail) },
    ) {
        self.item = item
        self.showsAffixCount = showsAffixCount
        self.isLocked = isLocked
        self.showsName = showsName
        self.reservesLabelSpace = reservesLabelSpace
        self.presentation = presentation
        self.appliesCardSurface = appliesCardSurface
        self.isSelected = isSelected
        self.shine = shine
        self.shineLineWidth = shineLineWidth
        self.art = art
    }

    private var resolvedShine: Shine {
        shine ?? item.displayShine
    }

    private var borderShine: Shine {
        if item.isCorrupted, item.rarity != .unique {
            return .corruption
        }
        return resolvedShine
    }

    public var body: some View {
        ProductCardShell(
            isLocked: isLocked,
            isSelected: isSelected,
            appliesCardSurface: appliesCardSurface,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shine: isLocked ? .none : borderShine,
            shineLineWidth: shineLineWidth,
            art: { art(item) },
            label: {
                if isLocked {
                    Text(balanced: item.localizedDisplayName(locale: locale))
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                } else {
                    switch presentation {
                    case .standard:
                        standardLabel
                    case .reveal:
                        revealLabel
                    }
                }
            },
        )
    }

    private var standardLabel: some View {
        ItemCardLabel(item: item, showsAffixCount: showsAffixCount, shine: shine)
    }

    private var revealLabel: some View {
        VStack(spacing: TrinketDesign.Spacing.tight) {
            TrinketRarityLabel(
                rarity: item.rarity,
                labelOverride: item.isTrinket ? String(localized: L10n.ui_itemcard_trinket_ae23c) : nil,
            )

            Text(balanced: item.localizedDisplayName(locale: locale))
                .trinketTypography(.sectionDisplay)
                .shineText(shine ?? item.displayTextShine)
                .multilineTextAlignment(.center)
                .trinketFittedText()
        }
    }
}
