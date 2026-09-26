import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BlacksmithForgeView: View {
    @Namespace private var resultNamespace
    @State private var path: [BlacksmithForgeRoute] = []
    @State private var browsingDetent: PresentationDetent = .medium
    @State private var detent: PresentationDetent = .medium
    @State private var visibleIDs: Set<String> = []

    private static let workDetent = PresentationDetent.height(520)

    var body: some View {
        NavigationStack(path: $path) {
            recipeGrid
                .navigationTitle("Forge")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: BlacksmithForgeRoute.self) { route in
                    switch route {
                    case let .recipe(recipe):
                        BlacksmithForgePreview(recipe: recipe, resultNamespace: resultNamespace) { item, celebrates in
                            withAnimation {
                                path.append(.result(recipeID: recipe.id, item: item, celebrates: celebrates))
                            }
                        }
                    case let .result(recipeID, item, celebrates):
                        BlacksmithForgedItemView(item: item, celebrates: celebrates)
                            .navigationTransition(.zoom(sourceID: recipeID, in: resultNamespace))
                    }
                }
        }
        .tint(TrinketDesign.Colors.accent)
        .presentationDetents([.medium, Self.workDetent, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .trinketSheetSurface()
        .onChange(of: path) { _, path in
            withAnimation {
                switch path.last {
                case nil:
                    detent = browsingDetent
                case .recipe:
                    detent = Self.workDetent
                case .result:
                    detent = .large
                }
            }
        }
        .onChange(of: detent) { _, detent in
            if path.isEmpty {
                browsingDetent = detent
            }
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeSheet)
    }

    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: TrinketDesign.Layout.collectionGridItems, spacing: TrinketDesign.Spacing.large) {
                ForEach(BlacksmithRecipe.all) { recipe in
                    Button { withAnimation { path.append(.recipe(recipe)) } } label: {
                        BlacksmithBaseCard(recipe: recipe, thumbnail: true)
                    }
                    .trinketArtworkCardButtonStyle()
                    .accessibilityLabel(recipe.baseType.name)
                    .accessibilityIdentifier(AccessibilityID.Homestead.forgeRecipe(recipe.id))
                    .onAppear { visibleIDs.insert(recipe.id) }
                    .onDisappear { visibleIDs.remove(recipe.id) }
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .trinketScreenBackground()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeGrid)
        .task(id: visibleIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: BlacksmithRecipe.all,
                visibleIDs: visibleIDs,
                currentVisibleIDs: { visibleIDs },
                thumbnailName: { $0.forgeArtwork?.thumbnailImageName ?? $0.forgeArtwork?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
        }
    }
}

struct BlacksmithBaseCard: View {
    let recipe: BlacksmithRecipe
    var thumbnail = false

    var body: some View {
        ProductCardShell {
            if let artwork = recipe.forgeArtwork {
                Image.preparedAsset(artwork, displaySize: thumbnail ? .compact : .full)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .decorativePreparedArtwork()
            } else {
                PlaceholderArtwork(.item)
            }
        } label: {
            Text(balanced: recipe.baseType.name)
                .trinketTypography(.cardLabel)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .trinketFittedText()
        }
    }
}

extension BlacksmithRecipe {
    var forgeArtwork: ItemArtReference? {
        ArtCatalog.itemArtByID["\(baseID)-basic"]
    }
}

/// The crafting entry uses an anvil silhouette; SF Symbols has no anvil glyph.
struct BlacksmithAnvilIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 0, y: 0.12), .init(x: 0.32, y: 0.12), .init(x: 0.32, y: 0.04),
            .init(x: 1, y: 0.04), .init(x: 1, y: 0.30), .init(x: 0.80, y: 0.42),
            .init(x: 0.66, y: 0.46), .init(x: 0.66, y: 0.72), .init(x: 0.84, y: 0.88),
            .init(x: 0.84, y: 1), .init(x: 0.28, y: 1), .init(x: 0.28, y: 0.88),
            .init(x: 0.46, y: 0.72), .init(x: 0.46, y: 0.46), .init(x: 0.26, y: 0.40),
            .init(x: 0.10, y: 0.28),
        ]
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}

private enum BlacksmithForgeRoute: Hashable {
    case recipe(BlacksmithRecipe)
    case result(recipeID: String, item: InventoryItem, celebrates: Bool)
}
