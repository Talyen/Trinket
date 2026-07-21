import SwiftUI
import TrinketDesignSystem

/// Category title + chevron NavigationLink over a horizontal peek shelf.
/// Used by Collection browse and the stage party picker.
@MainActor
struct CategoryBrowseShelf<Destination: View, Content: View>: View {
    let title: String
    var linkAccessibilityIdentifier: String?
    var sectionAccessibilityIdentifier: String?
    var shelfContentIdentity: String = ""
    var shelfAnimation: Animation?
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            NavigationLink {
                destination()
            } label: {
                categoryHeader
            }
            .trinketQuietTapButtonStyle()
            .modifier(OptionalAccessibilityIdentifier(linkAccessibilityIdentifier))

            horizontalShelf
        }
        .modifier(OptionalAccessibilityIdentifier(sectionAccessibilityIdentifier))
    }

    private var categoryHeader: some View {
        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
            Text(title)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .trinketTypography(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .contentShape(Rectangle())
    }

    private var horizontalShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: TrinketDesign.Metrics.collectionShelfCardSpacing) {
                content()
            }
            .scrollTargetLayout()
            .padding(.vertical, TrinketDesign.Metrics.shelfVerticalPadding)
            .modifier(OptionalShelfAnimation(animation: shelfAnimation, value: shelfContentIdentity))
        }
        .contentMargins(
            .horizontal,
            TrinketDesign.Metrics.collectionShelfHorizontalMargin,
            for: .scrollContent
        )
        .scrollTargetBehavior(.viewAligned)
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private struct OptionalShelfAnimation: ViewModifier {
    let animation: Animation?
    let value: String

    func body(content: Content) -> some View {
        if let animation {
            content.animation(animation, value: value)
        } else {
            content
        }
    }
}
