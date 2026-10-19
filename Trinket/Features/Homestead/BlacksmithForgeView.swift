import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct BlacksmithForgeView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.locale) private var locale
    @Namespace private var resultNamespace
    @State private var path: [BlacksmithForgeRoute] = []
    @State private var browsingDetent: PresentationDetent = .medium
    @State private var detent: PresentationDetent = .medium
    @State private var focusedIDs: [String]?
    @State private var visibleIDs: Set<String> = []

    let buildingID: HomesteadNodeID
    private var recipes: [EquipmentRecipe] {
        EquipmentRecipe.recipes(for: buildingID)
    }

    init(buildingID: HomesteadNodeID = .blacksmithForge, initialRecipeID: String? = nil) {
        self.buildingID = buildingID
        if let initialRecipeID, let recipe = EquipmentRecipe.matching(initialRecipeID), recipe.buildingID == buildingID {
            _path = State(initialValue: [.recipe(recipe)])
            _detent = State(initialValue: recipe.researchID == nil ? Self.workDetent : .large)
        }
    }

    private var focusedRecipes: [EquipmentRecipe] {
        focusedIDs?.compactMap(EquipmentRecipe.matching) ?? recipes.filter { $0.researchID != nil }
    }

    private static let workDetent = PresentationDetent.height(520)

    var body: some View {
        NavigationStack(path: $path) {
            recipeGrid
                .navigationTitle(buildingID == .blacksmithForge ? String(localized: L10n.ui_blacksmithforgeview_forge_8899e) :
                    String(localized: L10n.library_craft))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: BlacksmithForgeRoute.self) { route in
                    switch route {
                    case let .recipe(recipe):
                        BlacksmithForgePreview(recipe: recipe, resultNamespace: resultNamespace, onOpenResult: { item, celebrates in
                            withAnimation { path.append(.result(recipeID: recipe.id, item: item, celebrates: celebrates)) }
                        }, onViewResearch: { id in navigate(.project(id)) })
                    case let .project(id):
                        if let project = ResearchProject.matching(id) {
                            LibraryResearchProjectView(project: project, onRecipe: { navigate(.recipe($0)) }, onEnemy: { enemy in
                                navigate(.enemy(LibraryEnemyDetail.snapshot(enemy, roster: playerSave.roster)))
                            })
                        }
                    case let .enemy(detail):
                        if playerSave.library.isReadable, playerSave.library.progress.encounteredEnemyIDs.contains(detail.id) {
                            LibraryEnemyDetailContent(detail: detail)
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
                case let .recipe(recipe):
                    detent = recipe.researchID == nil ? Self.workDetent : .large
                case .project, .enemy, .result:
                    detent = .large
                }
            }
        }
        .onChange(of: detent) { _, detent in
            if path.isEmpty {
                browsingDetent = detent
            }
        }
        .onAppear {
            guard focusedIDs == nil else { return }
            let focused = recipes.filter { $0.researchID != nil }
            let learned = playerSave.library.progress.unlockedRecipeIDs
            focusedIDs = (focused.filter { learned.contains($0.id) } + focused.filter { !learned.contains($0.id) }).map(\.id)
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeSheet)
    }

    private var recipeGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                if buildingID == .archeryRange {
                    Text(L10n.library_standard_recipes).trinketTypography(.sectionTitle)
                }
                LazyVGrid(columns: TrinketDesign.Layout.collectionGridItems, spacing: TrinketDesign.Spacing.large) {
                    ForEach(recipes.filter { $0.researchID == nil }) { recipe in
                        Button { withAnimation { path.append(.recipe(recipe)) } } label: {
                            BlacksmithBaseCard(recipe: recipe, thumbnail: true)
                        }
                        .trinketArtworkCardButtonStyle()
                        .accessibilityLabel(recipe.baseType.localizedName(locale: locale))
                        .accessibilityIdentifier(AccessibilityID.Homestead.forgeRecipe(recipe.id))
                        .onAppear { visibleIDs.insert(recipe.id) }
                        .onDisappear { visibleIDs.remove(recipe.id) }
                    }
                }
                if buildingID == .archeryRange {
                    Text(L10n.library_focused_recipes).trinketTypography(.sectionTitle)
                    ForEach(focusedRecipes) { recipe in
                        Button { navigate(.recipe(recipe)) } label: {
                            HStack(spacing: TrinketDesign.Spacing.medium) {
                                LibraryRecipeArtwork(recipe: recipe).frame(width: 54)
                                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                                    Text(LibraryCopy.recipe(recipe, locale: locale)).foregroundStyle(.primary)
                                    if !playerSave.library.progress.unlockedRecipeIDs.contains(recipe.id), let id = recipe.researchID {
                                        Text(LibraryCopy.title(id, locale: locale)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.Homestead.forgeRecipe(recipe.id))
                    }
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .accessibilityIdentifier(AccessibilityID.Homestead.forgeGrid)
        .task(id: visibleIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: recipes,
                visibleIDs: visibleIDs,
                currentVisibleIDs: { visibleIDs },
                thumbnailName: { $0.forgeArtwork?.thumbnailImageName ?? $0.forgeArtwork?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
        }
    }

    private func navigate(_ route: BlacksmithForgeRoute) {
        if let index = path.firstIndex(of: route) {
            path = Array(path.prefix(through: index))
        } else {
            path.append(route)
        }
    }
}

struct BlacksmithBaseCard: View {
    @Environment(\.locale) private var locale
    let recipe: BlacksmithRecipe
    var thumbnail = false

    var body: some View {
        ProductCardShell {
            if let artwork = recipe.forgeArtwork {
                PreparedArtworkImage(artwork, displaySize: thumbnail ? .compact : .full)
                    .aspectRatio(contentMode: .fill)
                    .decorativePreparedArtwork()
            } else {
                PlaceholderArtwork(.item)
            }
        } label: {
            Text(balanced: recipe.baseType.localizedName(locale: locale))
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
    case project(String)
    case enemy(CombatantCardDetail)
    case result(recipeID: String, item: InventoryItem, celebrates: Bool)
}
