import SwiftUI
import TrinketContent
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport

extension View {
    func fullGameOfferHost() -> some View {
        modifier(FullGameOfferHost())
    }
}

private struct FullGameOfferHost: ViewModifier {
    @State private var offer: PreparedFullGameOffer?
    @State private var preparation: Task<Void, Never>?
    @State private var pinnedNames: [String] = []

    func body(content: Content) -> some View {
        content
            .environment(\.requestFullGameOffer, present)
            .sheet(item: $offer, onDismiss: releaseArtwork) { offer in
                NavigationStack {
                    FullGameOfferView(artworkName: offer.artworkName)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                preparation?.cancel()
                if offer == nil {
                    releaseArtwork()
                }
            }
    }

    private func present(_ requested: FullGameOfferOrigin) {
        guard offer == nil, preparation == nil else { return }
        preparation = Task { @MainActor in
            let artworkName = artworkName(for: requested)
            let names = artworkName.map { [$0] } ?? []
            await PreparedArtworkCache.shared.prepareAndPin(names: names)
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: names)
                preparation = nil
                return
            }
            pinnedNames = names
            offer = PreparedFullGameOffer(id: requested, artworkName: artworkName)
            preparation = nil
        }
    }

    private func artworkName(for origin: FullGameOfferOrigin) -> String? {
        let contextualName: String? = switch origin {
        case let .campaign(chapter):
            ArtCatalog.backgroundArtByID["chapter-\(chapter)"]?.imageName
        case let .spire(spire, _):
            ArtCatalog.backgroundArtByID["spire-\(spire.rawValue)"]?.imageName
        case .labyrinth:
            ArtCatalog.backgroundArtByID["labyrinth"]?.imageName
        case let .combatant(id):
            GameContent.combatant(matching: id)?.artReference?.imageName
        case .options:
            nil
        }
        return contextualName ?? ArtCatalog.backgroundArtByID["chapter-4"]?.imageName
    }

    private func releaseArtwork() {
        PreparedArtworkCache.shared.releasePins(names: pinnedNames)
        pinnedNames = []
    }
}

private struct PreparedFullGameOffer: Identifiable {
    let id: FullGameOfferOrigin
    let artworkName: String?
}
