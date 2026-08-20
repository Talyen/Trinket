import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct AbilitySummaryGrid: View {
    let combatant: Combatant
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    /// Called by the parent when the user taps an editable ability slot. The parent owns
    /// the navigation/presentation so no nested sheet is needed here.
    var onSelectTier: ((AbilityTier) -> Void)?
    /// Called when viewing (not editing) and the user taps a filled ability slot.
    var onViewAbility: ((Ability) -> Void)?
    /// Called on a filled slot long-press (editing or viewing).
    var onInspectAbility: ((Ability) -> Void)?

    public init(
        combatant: Combatant,
        loadout: Binding<AbilityLoadout>,
        allowsEditing: Bool,
        onSelectTier: ((AbilityTier) -> Void)? = nil,
        onViewAbility: ((Ability) -> Void)? = nil,
        onInspectAbility: ((Ability) -> Void)? = nil
    ) {
        self.combatant = combatant
        _loadout = loadout
        self.allowsEditing = allowsEditing
        self.onSelectTier = onSelectTier
        self.onViewAbility = onViewAbility
        self.onInspectAbility = onInspectAbility
    }

    public var body: some View {
        SlotSummaryGrid(
            slots: AbilityTier.allCases,
            isLocked: { _ in false },
            hasItem: { selectedAbility(for: $0) != nil },
            onSelect: allowsEditing ? onSelectTier : nil,
            onView: !allowsEditing ? { tier in
                if let ability = selectedAbility(for: tier) {
                    onViewAbility?(ability)
                }
            } : nil,
            onLongPress: onInspectAbility == nil ? nil : { tier in
                if let ability = selectedAbility(for: tier) {
                    onInspectAbility?(ability)
                }
            },
            accessibilityIdentifier: { "\($0.rawValue) ability slot" },
            card: { tier in
                if let ability = selectedAbility(for: tier) {
                    AbilityChoiceCard(ability: ability)
                } else {
                    EmptyAbilitySlotCard(tier: tier)
                }
            }
        )
        .id(combatant.id)
    }

    private func selectedAbility(for tier: AbilityTier) -> Ability? {
        loadout.ability(for: tier)
    }
}
