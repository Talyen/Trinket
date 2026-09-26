import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public enum NodeModifierPresentation {
    public static func style(for modifier: NodeModifierDefinition) -> Keyword.VisualStyle {
        switch modifier.effect {
        case let .damageDealt(keyword, _):
            keyword.visualStyle
        case let .damageTakenReduction(keyword, _):
            Keyword.VisualStyle(
                color: keyword.visualStyle.color,
                icon: keyword == .physical ? Keyword.block.visualStyle.icon : keyword.visualStyle.icon,
            )
        case .blockGained:
            Keyword.block.visualStyle
        case .leechGainedPercent:
            Keyword.leech.visualStyle
        case .startBattleBlock, .attackBlockRemoval:
            Keyword.block.visualStyle
        case .attackLeech:
            Keyword.leech.visualStyle
        case .attackPurge:
            Keyword.purge.visualStyle
        case let .reward(modifier):
            ModifierCaptionPresentation(modifier).style
        case .shopDiscountPercent:
            Keyword.VisualStyle(color: Keyword.gold.visualStyle.color, icon: .system("percent"))
        case .astralShopOffers:
            Keyword.VisualStyle(color: TrinketDesign.Colors.arcane, icon: .system("eye.fill"))
        }
    }
}
