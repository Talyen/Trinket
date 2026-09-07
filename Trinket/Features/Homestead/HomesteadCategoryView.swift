import SwiftUI
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
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TrinketDesign.Spacing.large) {
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
            NavigationStack {
                HomesteadWalletSheetContent()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showsWallet = false } label: { Label("Close", systemImage: "xmark") }
                                .accessibilityIdentifier(AccessibilityID.Homestead.closeSheetButton)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(TrinketDesign.Colors.surface)
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
            if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                names.append(art.imageName)
                if let thumb = art.thumbnailImageName {
                    names.append(thumb)
                }
            }
        }
        if let hero = ArtCatalog.backgroundArtByID[definitions.first?.category.artID ?? ""] {
            names.append(hero.imageName)
            if let thumb = hero.thumbnailImageName {
                names.append(thumb)
            }
        }
        return names
    }

    private func refreshImminentHomesteadArtworkPins() async {
        let next = Array(Set(Self.imminentHomesteadArtworkNames(for: definitions))).sorted()
        let previous = Set(pinnedHomesteadArtwork)
        let added = Set(next).subtracting(previous)
        let removed = previous.subtracting(Set(next))
        if !added.isEmpty {
            let addedNames = Array(added)
            await PreparedArtworkCache.shared.prepareAndPin(names: addedNames)
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: addedNames)
                return
            }
        }
        guard !Task.isCancelled else { return }
        if !removed.isEmpty {
            PreparedArtworkCache.shared.releasePins(names: Array(removed))
        }
        pinnedHomesteadArtwork = next
    }
}

extension HomesteadNodeCategory {
    var artID: String {
        switch self {
        case .farming: "wheatField"
        case .crafting: "blacksmithForge"
        case .alchemy: "alchemyLab"
        case .training: "hunterLodge"
        case .arcana: "moonlitSanctum"
        }
    }
}
