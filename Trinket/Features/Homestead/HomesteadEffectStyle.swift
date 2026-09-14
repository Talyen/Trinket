import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadEffectStyle {
    let symbol: String
    let tint: Color

    init(key: HomesteadEffectLine.Key) {
        switch key {
        case let .modifier(modifier, _):
            self.init(modifier: modifier)
        case .astralFind:
            self.init(symbol: "sparkles", tint: TrinketDesign.Colors.arcane)
        case .goldFind:
            self.init(keyword: .gold)
        case let .production(resource):
            self.init(symbol: Self.symbol(for: resource), tint: resource.tint)
        }
    }

    private init(symbol: String, tint: Color) {
        self.symbol = symbol
        self.tint = tint
    }

    private init(keyword: Keyword, symbol: String? = nil) {
        self.init(symbol: symbol ?? keyword.visualStyle.icon.symbolName, tint: keyword.visualStyle.color)
    }

    private init(modifier: AffixModifier) {
        switch modifier {
        case .maximumHealth:
            self.init(keyword: .health)
        case .healthRestored:
            self.init(keyword: .health, symbol: "heart.circle.fill")
        case .maximumMana:
            self.init(keyword: .mana)
        case let .damageDealt(keyword, _):
            self.init(keyword: keyword)
        case .poisonDamageDealtPercent:
            self.init(keyword: .poison)
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            self.init(keyword: keyword, symbol: "shield.fill")
        case .incomingDamageReductionPercent, .blockGained:
            self.init(keyword: .block)
        case .outgoingDamagePercent:
            self.init(keyword: .physical)
        case .companionDamageDealt:
            self.init(keyword: .physical, symbol: "pawprint.fill")
        case .dodgeChanceBonus:
            self.init(keyword: .dodge)
        case .leechGainedPercent, .leechHealing:
            self.init(keyword: .leech)
        case .goldGained, .goldGainedPercent:
            self.init(keyword: .gold)
        case .bleedDuration, .companionBleedDamageDealt:
            self.init(keyword: .bleed)
        }
    }

    private static func symbol(for resource: HomesteadResource) -> String {
        switch resource {
        case .food: "carrot.fill"
        case .herbs: "leaf.fill"
        case .crystal: "diamond.fill"
        case .hide: "square.stack.3d.up.fill"
        case .gold: "circle.circle.fill"
        case .wood: "tree.fill"
        case .stone: "mountain.2.fill"
        case .iron: "anvil.fill"
        }
    }
}
