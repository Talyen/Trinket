import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadCategoryView: View {
    let category: HomesteadNodeCategory
    var zoomNamespace: Namespace.ID

    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var showsWallet = false
    @State private var pinnedHomesteadArtwork: [String] = []

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
                        status: HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster),
                        zoomNamespace: zoomNamespace,
                    )
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
            .padding(.bottom, TrinketDesign.Layout.tabBarContentClearance)
        }
        .trinketScreenBackground()
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsWallet = true } label: { Label("Resources", systemImage: "bag") }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityID.Homestead.walletButton)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.gallery)
        .sheet(isPresented: $showsWallet) {
            HomesteadWalletSheet(onClose: { showsWallet = false })
        }
        .task(id: imminentHomesteadArtworkKey) {
            await refreshImminentHomesteadArtworkPins()
        }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedHomesteadArtwork)
            pinnedHomesteadArtwork = []
        }
    }

    private var imminentHomesteadArtworkKey: [String] {
        Self.imminentHomesteadArtworkNames(for: definitions).sorted()
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
        pinnedHomesteadArtwork = await ArtworkPinSet.refresh(
            next: Self.imminentHomesteadArtworkNames(for: definitions),
            current: pinnedHomesteadArtwork,
        )
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
                    .shadow(color: TrinketDesign.Colors.accent.opacity(status.canBuildOrUpgrade ? 0.4 : 0), radius: 8)
                    .overlay(alignment: .bottomTrailing) {
                        if !status.isUnlocked {
                            Image(systemName: "lock.fill")
                                .trinketTypography(.body)
                                .trinketOnArtText()
                                .padding(TrinketDesign.Spacing.medium)
                                .accessibilityHidden(true)
                        }
                    }

                HomesteadTierProgress(currentTier: status.currentTier, totalTiers: definition.maxTier)
                    .frame(maxWidth: 132)
                    .accessibilityHidden(true)

                Text(balanced: definition.title)
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
        .accessibilityValue("\(status.currentTier) of \(definition.maxTier) upgrades")
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    @MainActor
    @ViewBuilder
    private var artwork: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            FocalBackgroundArtwork(art: art, displaySize: .compact)
                .saturation(status.isUnlocked ? 1 : 0.35)
        } else {
            TrinketDesign.Colors.surface
        }
    }
}
