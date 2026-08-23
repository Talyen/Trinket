import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Keyword-art card for a talent tree: prepared art (or keyword placeholder),
/// the tree name, and a progress caption, with keyword shine when choosable.
public struct TalentTreeCard: View {
    let tree: TalentTree
    let caption: String
    var isLocked = false
    var lockedText = "Locked"
    var showsShine = true
    var accessibilityID: String?

    public init(
        tree: TalentTree,
        caption: String,
        isLocked: Bool = false,
        lockedText: String = "Locked",
        showsShine: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.tree = tree
        self.caption = caption
        self.isLocked = isLocked
        self.lockedText = lockedText
        self.showsShine = showsShine
        self.accessibilityID = accessibilityID
    }

    public var body: some View {
        ProductCardShell(
            isLocked: isLocked,
            lockedText: lockedText,
            shineKeywords: showsShine ? [tree.keyword] : nil,
            accessibilityID: accessibilityID,
            art: {
                if let artReference = tree.keyword.artReference {
                    Image.preparedAsset(artReference, displaySize: .compact)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .decorativePreparedArtwork()
                } else {
                    PlaceholderArtwork(tree.keyword.visualStyle)
                }
            },
            label: {
                VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                    Text(tree.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(caption)
                        .trinketTypography(.badge)
                        .foregroundStyle(.tertiary)
                }
            }
        )
    }
}
