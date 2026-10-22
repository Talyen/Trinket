import Observation
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
    @State private var presentation = FullGameOfferPresentation()

    func body(content: Content) -> some View {
        @Bindable var presentation = presentation
        return content
            .environment(\.requestFullGameOffer, presentation.requestAction)
            .sheet(item: $presentation.offer, onDismiss: presentation.releaseArtwork) { offer in
                NavigationStack {
                    FullGameOfferView(artwork: offer.artwork)
                }
                .trinketSheetSurface()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                presentation.disappeared()
            }
    }
}

@MainActor
@Observable
private final class FullGameOfferPresentation {
    var offer: PreparedFullGameOffer?
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var artworkLease: PreparedArtworkLease?
    @ObservationIgnored lazy var requestAction = FullGameOfferRequestAction { [weak self] origin in
        self?.present(origin)
    }

    func disappeared() {
        preparation?.cancel()
        if offer == nil {
            releaseArtwork()
        }
    }

    func present(_ requested: FullGameOfferOrigin) {
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

    func releaseArtwork() {
        artworkLease?.release()
        artworkLease = nil
    }
}

private struct PreparedFullGameOffer: Identifiable {
    let id: FullGameOfferOrigin
    let artwork: FullGameOfferArtwork?
}
