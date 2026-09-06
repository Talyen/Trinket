import SwiftUI
import TrinketContent
import TrinketDesignSystem

public enum ItemCardPresentation {
    case standard
    case reveal
}

public struct ItemCard<Art: View>: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var presentation: ItemCardPresentation = .standard
    var appliesCardSurface: Bool = true
    var isSelected = false
    var fadesLabel = false
    var shine: Shine?
    var shineLineWidth: CGFloat = 2
    @ViewBuilder private var art: () -> Art

    @State private var labelOpacity = 1.0

    public init(
        item: InventoryItem,
        showsAffixCount: Bool,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        presentation: ItemCardPresentation = .standard,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false,
        fadesLabel: Bool = false,
        shine: Shine? = nil,
        shineLineWidth: CGFloat = 2,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.item = item
        self.showsAffixCount = showsAffixCount
        self.showsName = showsName
        self.reservesLabelSpace = reservesLabelSpace
        self.presentation = presentation
        self.appliesCardSurface = appliesCardSurface
        self.isSelected = isSelected
        self.fadesLabel = fadesLabel
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
            isSelected: isSelected,
            appliesCardSurface: appliesCardSurface,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shine: borderShine,
            shineLineWidth: shineLineWidth,
            art: art,
            label: {
                switch presentation {
                case .standard:
                    standardLabel
                case .reveal:
                    revealLabel
                }
            },
        )
        .onAppear {
            guard fadesLabel else { return }
            withAnimation(.easeOut(duration: TrinketMotion.Content.cardDissolveDuration)) {
                labelOpacity = 0
            }
        }
    }

    private var standardLabel: some View {
        ItemCardLabel(item: item, showsAffixCount: showsAffixCount, shine: shine)
            .opacity(labelOpacity)
    }

    private var revealLabel: some View {
        VStack(spacing: TrinketDesign.Spacing.extraSmall) {
            TrinketRarityLabel(
                rarity: item.rarity,
                labelOverride: item.isTrinket ? "Trinket" : nil,
            )

            Text(balanced: item.displayName)
                .trinketTypography(.sectionDisplay)
                .shineText(shine ?? item.displayTextShine)
                .multilineTextAlignment(.center)
                .trinketFittedText()
        }
        .opacity(labelOpacity)
    }
}

public extension ItemCard where Art == ItemArtwork {
    init(
        item: InventoryItem,
        showsAffixCount: Bool,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        presentation: ItemCardPresentation = .standard,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false,
        fadesLabel: Bool = false,
        shine: Shine? = nil,
        shineLineWidth: CGFloat = 2,
    ) {
        self.init(
            item: item,
            showsAffixCount: showsAffixCount,
            showsName: showsName,
            reservesLabelSpace: reservesLabelSpace,
            presentation: presentation,
            appliesCardSurface: appliesCardSurface,
            isSelected: isSelected,
            fadesLabel: fadesLabel,
            shine: shine,
            shineLineWidth: shineLineWidth,
        ) {
            ItemArtwork(item: item, variant: .thumbnail)
        }
    }
}
