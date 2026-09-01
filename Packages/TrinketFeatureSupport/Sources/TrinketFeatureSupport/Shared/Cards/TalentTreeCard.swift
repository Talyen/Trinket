import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct TalentTreeCard: View {
    let tree: TalentTree
    let caption: String
    var isLocked = false
    var showsShine = true
    var accessibilityID: String?

    public init(
        tree: TalentTree,
        caption: String,
        isLocked: Bool = false,
        showsShine: Bool = true,
        accessibilityID: String? = nil,
    ) {
        self.tree = tree
        self.caption = caption
        self.isLocked = isLocked
        self.showsShine = showsShine
        self.accessibilityID = accessibilityID
    }

    public var body: some View {
        ProductCardShell(
            isLocked: isLocked,
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
                VStack(spacing: TrinketDesign.Spacing.extraSmall) {
                    Text(balanced: tree.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                    Text(balanced: caption)
                        .trinketTypography(.badge)
                        .foregroundStyle(.tertiary)
                        .trinketFittedText()
                }
            },
        )
    }
}
