import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ResearchCompletionNotice: View {
    @Environment(\.locale) private var locale
    let ids: [String]

    var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(TrinketDesign.Colors.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                Text(L10n.library_completion).trinketTypography(.rowTitle)
                if ids.count == 1, let id = ids.first, let project = ResearchProject.matching(id) {
                    if let recipe = project.recipeID.flatMap(EquipmentRecipe.matching) {
                        Text(LibraryCopy.recipe(recipe, locale: locale))
                        Text(ContentCopy.localized("Archery Range", locale: locale)).foregroundStyle(.secondary)
                    } else {
                        Text(LibraryCopy.title(id, locale: locale)).foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.library_completion_summary(ids.count)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(TrinketDesign.Spacing.medium)
        .trinketMaterial(.frostedPanel, cornerRadius: TrinketDesign.Corners.card)
        .allowsHitTesting(false)
    }
}
