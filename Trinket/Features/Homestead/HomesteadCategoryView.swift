import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadCategoryView: View {
    let category: HomesteadNodeCategory
    var zoomNamespace: Namespace.ID

    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var showsWallet = false
    @State private var artworkPins = PreparedArtworkPinSet()

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    private var definitions: [HomesteadNodeDefinition] {
        GameContent.homesteadNodes.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            // Shared collection grid spec (adaptive 150–190): renders the same
            // two columns as the previous hardcoded pair on every portrait
            // iPhone, and stays in sync with Collection when the spec changes.
            LazyVGrid(columns: TrinketDesign.Layout.collectionGridItems, spacing: TrinketDesign.Spacing.large) {
                ForEach(definitions) { definition in
                    HomesteadProjectTile(
                        definition: definition,
                        status: HomesteadProjectStatus(definition: definition, homestead: homestead, gold: roster.gold),
                        zoomNamespace: zoomNamespace,
                    )
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .trinketScreenBackground()
        .navigationTitle(ContentCopy.localized(category.rawValue))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsWallet = true } label: { Label(
                    String(localized: L10n.ui_homesteadcategoryview_resources_e89b3),
                    systemImage: "bag",
                ) }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(AccessibilityID.Homestead.walletButton)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.gallery)
        .sheet(isPresented: $showsWallet) {
            HomesteadWalletSheet(onClose: { showsWallet = false })
        }
        .task(id: category) {
            await refreshImminentHomesteadArtworkPins()
        }
        .onDisappear {
            artworkPins.release()
        }
    }

    static func imminentHomesteadArtworkNames(for definitions: [HomesteadNodeDefinition]) -> [String] {
        var names: [String] = []
        for definition in definitions {
            if let portrait = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
                names.append(portrait.imageName)
                if let thumbnail = portrait.thumbnailImageName {
                    names.append(thumbnail)
                }
            }
        }
        return names
    }

    private func refreshImminentHomesteadArtworkPins() async {
        await artworkPins.prepare(names: Self.imminentHomesteadArtworkNames(for: definitions))
    }
}

struct HomesteadProjectTile: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    var zoomNamespace: Namespace.ID

    var body: some View {
        NavigationLink(value: HomesteadRoute.node(definition.id)) {
            VStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
                artwork
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: TrinketDesign.Corners.card)
                            .strokeBorder(
                                TrinketDesign.Colors.subtleStroke,
                                lineWidth: 1,
                            )
                    }

                GameLabel(definition.title, balanced: true)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .matchedTransitionSource(id: definition.id, in: zoomNamespace)
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityValue(Text(L10n.ui_homesteadcategoryview_1_of_2_upgrades_67fe8("\(status.currentTier)", "\(definition.maxTier)")))
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    @MainActor
    @ViewBuilder
    private var artwork: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            FocalBackgroundArtwork(art: art, displaySize: .compact)
                .saturation(status.currentTier > 0 ? 1 : 0.35)
        } else {
            TrinketDesign.Colors.surface
        }
    }
}
