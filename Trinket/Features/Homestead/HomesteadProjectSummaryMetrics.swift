import SwiftUI

struct HomesteadProjectSummaryMetrics {
    let spacing: CGFloat
    let titleFont: Font
    let tierFont: Font
    let bonusFont: Font
    var titleForeground: Color = .primary
    var bonusLineLimit: Int?
    var showsFeaturedLabel = false
    var showsInlineStatusBadge = false

    static let featured = HomesteadProjectSummaryMetrics(
        spacing: 7,
        titleFont: .title2.weight(.bold),
        tierFont: .subheadline.monospacedDigit().weight(.semibold),
        bonusFont: .subheadline,
        showsFeaturedLabel: true
    )

    static func compact(isUnlocked: Bool) -> HomesteadProjectSummaryMetrics {
        HomesteadProjectSummaryMetrics(
            spacing: 6,
            titleFont: .headline,
            tierFont: .caption.monospacedDigit().weight(.semibold),
            bonusFont: .caption,
            titleForeground: isUnlocked ? .primary : .secondary,
            bonusLineLimit: 2,
            showsInlineStatusBadge: true
        )
    }
}
