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

    @Environment(PlayerSaveStore.self) private var playerSave
    @Namespace private var zoomNamespace
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
        HomesteadHeroScreen(
            title: category.rawValue,
            homestead: homestead,
            roster: roster,
        ) {
            categoryHeroArt
        } bodyContent: {
            HomesteadProjectSection(
                category: category,
                definitions: definitions,
                homestead: homestead,
                roster: roster,
                zoomNamespace: zoomNamespace,
                showsCategoryHeader: false,
            )
        }
        .navigationDestination(for: HomesteadNodeDefinition.self) { definition in
            HomesteadNodeDetailView(definition: definition)
                .navigationTransition(.zoom(sourceID: definition.id, in: zoomNamespace))
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

    @ViewBuilder
    private var categoryHeroArt: some View {
        if let art = ArtCatalog.backgroundArtByID[category.artID] {
            HomesteadFocalArtwork(art: art)
        } else {
            TrinketDesign.Colors.surface
        }
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
