import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct ItemArtwork: View {
    public enum Variant {
        case full
        case thumbnail
    }

    let item: InventoryItem
    var variant: Variant = .full
    var contentMode: ContentMode = .fill

    public init(
        item: InventoryItem,
        variant: Variant = .full,
        contentMode: ContentMode = .fill,
    ) {
        self.item = item
        self.variant = variant
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let artReference = item.artReference {
                Image.preparedAsset(
                    artReference,
                    displaySize: variant == .thumbnail ? .compact : .full,
                )
                .resizable()
                .interpolation(variant == .thumbnail ? .low : .medium)
                .aspectRatio(contentMode: contentMode)
                .decorativePreparedArtwork()
            } else {
                placeholderArt
            }
        }
        .clipped()
    }

    private var placeholderArt: some View {
        PlaceholderArtwork(.item)
    }
}
