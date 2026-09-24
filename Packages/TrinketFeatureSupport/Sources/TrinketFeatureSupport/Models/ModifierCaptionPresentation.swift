import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct ModifierCaptionPresentation: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let style: Keyword.VisualStyle

    public init(_ modifier: LabyrinthModifierDefinition) {
        id = modifier.id.rawValue
        title = modifier.title
        description = modifier.effect.description
        style = LabyrinthModifierPresentation.style(for: modifier)
    }

    public init(_ modifier: RewardModifier) {
        id = modifier.rawValue
        title = modifier.title
        description = modifier.description
        if let resource = modifier.materialFocus {
            style = Keyword.VisualStyle(color: resource.tint, icon: resource.icon)
        } else {
            style = switch modifier {
            case .gold: Keyword.gold.visualStyle
            case .experience: Keyword.VisualStyle(color: TrinketDesign.Colors.informational, icon: .system("book.fill"))
            case .materials: Keyword.VisualStyle(color: HomesteadResource.wood.tint, icon: .system("shippingbox.fill"))
            case .astral: Keyword.VisualStyle(color: TrinketDesign.Colors.arcane, icon: .system("sparkles"))
            case .trinket: Keyword.VisualStyle(color: TrinketDesign.Colors.keywordMana, icon: .system("diamond.circle.fill"))
            case .unique: Keyword.VisualStyle(color: TrinketDesign.Colors.accent, icon: .system("crown.fill"))
            case .armsHoard: Keyword.physical.visualStyle
            case .armorHoard: Keyword.block.visualStyle
            case .ringHoard: Keyword.VisualStyle(color: TrinketDesign.Colors.arcane, icon: .system("circle"))
            case .amuletHoard: Keyword.VisualStyle(color: TrinketDesign.Colors.arcane, icon: .system("sparkle"))
            case .astralHoard: Keyword.VisualStyle(color: TrinketDesign.Colors.arcane, icon: .system("sparkles"))
            case .trinketHoard: Keyword.VisualStyle(color: TrinketDesign.Colors.keywordMana, icon: .system("diamond.circle.fill"))
            case .uniqueHoard: Keyword.VisualStyle(color: TrinketDesign.Colors.accent, icon: .system("crown.fill"))
            case let .keyword(keyword): keyword.visualStyle
            default: Keyword.gold.visualStyle
            }
        }
    }
}
