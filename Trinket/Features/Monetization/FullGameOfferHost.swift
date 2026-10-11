import SwiftUI
import TrinketContent
import TrinketDesignSystem
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
    @State private var artworkLease: PreparedArtworkLease?

    func body(content: Content) -> some View {
        content
            .environment(\.requestFullGameOffer, present)
            .sheet(item: $offer, onDismiss: releaseArtwork) { offer in
                NavigationStack {
                    FullGameOfferView(artwork: offer.artwork)
                }
                .trinketSheetSurface()
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
            let artwork = artwork(for: requested)
            let names = artwork.map { [$0.imageName] } ?? []
            let lease = await PreparedArtworkLease(names: names)
            guard !Task.isCancelled else {
                lease.release()
                preparation = nil
                return
            }
            artworkLease = lease
            offer = PreparedFullGameOffer(id: requested, artwork: artwork)
            preparation = nil
        }
    }

    private func artwork(for origin: FullGameOfferOrigin) -> FullGameOfferArtwork? {
        let contextualArtwork: FullGameOfferArtwork? = switch origin {
        case let .campaign(chapter):
            backgroundArtwork(id: "chapter-\(chapter)")
        case let .spire(spire, _):
            backgroundArtwork(id: "spire-\(spire.rawValue)")
        case .labyrinth:
            backgroundArtwork(id: "gameModeLabyrinth")
        case let .combatant(id):
            GameContent.combatant(matching: id)?.artReference.map {
                FullGameOfferArtwork(imageName: $0.imageName, focalPoint: $0.focalPoint)
            }
        case .options:
            nil
        }
        return contextualArtwork ?? backgroundArtwork(id: "chapter-4")
    }

    private func backgroundArtwork(id: String) -> FullGameOfferArtwork? {
        ArtCatalog.backgroundArtByID[id].map {
            FullGameOfferArtwork(imageName: $0.imageName, focalPoint: $0.focalPoint)
        }
    }

    private func releaseArtwork() {
        artworkLease?.release()
        artworkLease = nil
    }
}

private struct PreparedFullGameOffer: Identifiable {
    let id: FullGameOfferOrigin
    let artwork: FullGameOfferArtwork?
}
