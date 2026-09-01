import SwiftUI
import TrinketDesignSystem

@MainActor
public struct CategoryBrowseShelf<Destination: View, Content: View>: View {
    let title: String
    var linkAccessibilityIdentifier: String?
    var sectionAccessibilityIdentifier: String?
    var shelfContentIdentity: String = ""
    var shelfAnimation: Animation?
    var totalCount: Int?
    var previewLimit: Int

    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let content: () -> Content

    public init(
        title: String,
        linkAccessibilityIdentifier: String? = nil,
        sectionAccessibilityIdentifier: String? = nil,
        shelfContentIdentity: String = "",
        shelfAnimation: Animation? = nil,
        totalCount: Int? = nil,
        previewLimit: Int = TrinketDesign.Layout.collectionShelfPreviewLimit,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.linkAccessibilityIdentifier = linkAccessibilityIdentifier
        self.sectionAccessibilityIdentifier = sectionAccessibilityIdentifier
        self.shelfContentIdentity = shelfContentIdentity
        self.shelfAnimation = shelfAnimation
        self.totalCount = totalCount
        self.previewLimit = previewLimit
        self.destination = destination
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            NavigationLink {
                destination()
            } label: {
                categoryHeader
            }
            .trinketQuietTapButtonStyle()
            .trinketAccessibilityIdentifier(linkAccessibilityIdentifier)

            horizontalShelf
        }
        .trinketAccessibilityIdentifier(sectionAccessibilityIdentifier)
    }

    private var categoryHeader: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            Text(balanced: title)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .trinketTypography(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .contentShape(Rectangle())
    }

    private var horizontalShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: TrinketDesign.Layout.collectionShelfCardSpacing) {
                content()

                if let totalCount, totalCount > previewLimit {
                    NavigationLink {
                        destination()
                    } label: {
                        ViewAllShelfCard(
                            remainingCount: totalCount - previewLimit,
                            accessibilityIdentifier: AccessibilityID.Collection.viewAllCard(category: title),
                        )
                    }
                    .trinketQuietTapButtonStyle()
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, TrinketDesign.Layout.shelfVerticalPadding)
            .animation(shelfAnimation, value: shelfContentIdentity)
        }
        .contentMargins(
            .horizontal,
            TrinketDesign.Layout.collectionShelfHorizontalMargin,
            for: .scrollContent,
        )
        .scrollTargetBehavior(.viewAligned)
    }
}
