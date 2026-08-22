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
        contentMode: ContentMode = .fill
    ) {
        self.item = item
        self.variant = variant
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let imageName {
                Image.preparedAsset(named: imageName)
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

    private var imageName: String? {
        guard let artReference = item.artReference else { return nil }
        switch variant {
        case .full:
            return artReference.imageName
        case .thumbnail:
            return artReference.thumbnailImageName ?? artReference.imageName
        }
    }

    private var placeholderArt: some View {
        PlaceholderArtwork(.item)
    }
}
