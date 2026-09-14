import SwiftUI
import TrinketDesignSystem

@MainActor
public struct CategoryBrowseShelf<Destination: View, Content: View>: View {
    let title: String
    var linkAccessibilityIdentifier: String?
    var sectionAccessibilityIdentifier: String?
    var totalCount: Int?
    var previewLimit: Int
    let artworkNames: [String]
    @State private var requestID: UUID?
    @State private var artworkLease: PreparedArtworkLease?
    @State private var isPresented = false
    @State private var showsPending = false

    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let content: () -> Content

    public init(
        title: String,
        linkAccessibilityIdentifier: String? = nil,
        sectionAccessibilityIdentifier: String? = nil,
        totalCount: Int? = nil,
        previewLimit: Int = TrinketDesign.Layout.collectionShelfPreviewLimit,
        artworkNames: [String] = [],
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.linkAccessibilityIdentifier = linkAccessibilityIdentifier
        self.sectionAccessibilityIdentifier = sectionAccessibilityIdentifier
        self.totalCount = totalCount
        self.previewLimit = previewLimit
        self.artworkNames = artworkNames
        self.destination = destination
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            Button {
                requestID = UUID()
            } label: {
                categoryHeader
            }
            .trinketArtworkCardButtonStyle()
            .trinketAccessibilityIdentifier(linkAccessibilityIdentifier)

            horizontalShelf
        }
        .trinketAccessibilityIdentifier(sectionAccessibilityIdentifier)
        .navigationDestination(isPresented: $isPresented) {
            destination()
        }
        .task(id: requestID) {
            guard let requestID else { return }
            let lease = await PreparedArtworkLease(names: artworkNames)
            guard !Task.isCancelled, self.requestID == requestID else { return }
            artworkLease = lease
            isPresented = true
            self.requestID = nil
        }
        .task(id: requestID) {
            showsPending = false
            guard requestID != nil else { return }
            try? await Task.sleep(for: .seconds(TrinketMotion.Interaction.pendingIndicatorDelay))
            guard !Task.isCancelled else { return }
            showsPending = true
        }
        .onChange(of: isPresented) { _, presented in
            if !presented {
                artworkLease = nil
            }
        }
        .onDisappear {
            requestID = nil
            if !isPresented {
                artworkLease = nil
            }
        }
    }

    private var categoryHeader: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            Text(balanced: title)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.primary)
                .trinketFittedText()
            if showsPending {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: "chevron.right")
                    .trinketTypography(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
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
                    Button {
                        requestID = UUID()
                    } label: {
                        ViewAllShelfCard(
                            remainingCount: totalCount - previewLimit,
                            accessibilityIdentifier: AccessibilityID.Collection.viewAllCard(category: title),
                        )
                    }
                    .trinketArtworkCardButtonStyle()
                    .accessibilityLabel("View all \(title)")
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, TrinketDesign.Layout.shelfVerticalPadding)
        }
        .contentMargins(
            .horizontal,
            TrinketDesign.Layout.collectionShelfHorizontalMargin,
            for: .scrollContent,
        )
        .scrollTargetBehavior(.viewAligned)
    }
}
