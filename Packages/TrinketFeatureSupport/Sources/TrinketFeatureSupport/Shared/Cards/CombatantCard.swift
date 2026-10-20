import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct CombatantCard: View {
    let combatant: Combatant
    var isLocked: Bool = false
    var showsName: Bool = true
    var isSelected = false

    public init(
        combatant: Combatant,
        isLocked: Bool = false,
        showsName: Bool = true,
        isSelected: Bool = false,
    ) {
        self.combatant = combatant
        self.isLocked = isLocked
        self.showsName = showsName
        self.isSelected = isSelected
    }

    public var body: some View {
        ProductCardShell(
            isLocked: isLocked,
            isSelected: isSelected,
            showsLabel: showsName,
            art: {
                CombatantArtwork(combatant: combatant, variant: .card)
            },
            label: {
                GameLabel(combatant.name, balanced: true)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
            },
        )
    }
}

public struct CollectionCombatantButton: View {
    @Environment(\.locale) private var locale
    let combatant: Combatant
    let isLocked: Bool
    var cardWidth: CGFloat? = 130
    var showsName: Bool = true
    let onSelect: () -> Void

    public init(
        combatant: Combatant,
        isLocked: Bool,
        cardWidth: CGFloat? = 130,
        showsName: Bool = true,
        onSelect: @escaping () -> Void,
    ) {
        self.combatant = combatant
        self.isLocked = isLocked
        self.cardWidth = cardWidth
        self.showsName = showsName
        self.onSelect = onSelect
    }

    public var body: some View {
        var name = ContentCopy.resource(combatant.name)
        name.locale = locale
        return Button(action: onSelect) {
            CombatantCard(
                combatant: combatant,
                isLocked: isLocked,
                showsName: showsName,
            )
            .frame(width: cardWidth)
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityLabel(isLocked
            ? Text(L10n.ui_combatantcard_1_locked_1871c(name))
            : Text(verbatim: ContentCopy.localized(combatant.name, locale: locale)))
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.collectionCard(name: combatant.name))
    }
}
