import SwiftUI

private struct ArtworkPresentationPreparation<Item: Hashable>: ViewModifier {
    @Binding var request: Item?
    @Binding var presentation: Item?
    let artworkNames: (Item) -> [String]
    @State private var lease: PreparedArtworkLease?

    func body(content: Content) -> some View {
        content
            .task(id: request) {
                guard !Task.isCancelled, let request else { return }
                let prepared = await PreparedArtworkLease(names: artworkNames(request))
                guard !Task.isCancelled, self.request == request else { return }
                lease = prepared
                presentation = request
                self.request = nil
            }
            .onChange(of: presentation) { _, current in
                if current == nil {
                    lease = nil
                }
            }
            .onDisappear {
                if presentation == nil {
                    release()
                }
            }
    }

    private func release() {
        request = nil
        lease = nil
    }
}

private struct PreparedArtworkSheet<Item: Hashable & Identifiable, Destination: View>: ViewModifier {
    @Binding var item: Item?
    let artworkNames: (Item) -> [String]
    let destination: (Item) -> Destination
    @State private var presentation: Item?
    @State private var lease: PreparedArtworkLease?

    func body(content: Content) -> some View {
        content
            .sheet(item: $presentation, onDismiss: {
                if presentation == nil {
                    item = nil
                    lease = nil
                }
            }, content: destination)
            .task(id: item) {
                guard !Task.isCancelled else { return }
                guard let item else {
                    presentation = nil
                    return
                }
                let prepared = await PreparedArtworkLease(names: artworkNames(item))
                guard !Task.isCancelled, self.item == item else { return }
                lease = prepared
                presentation = item
            }
            .onDisappear {
                if presentation == nil {
                    item = nil
                    lease = nil
                }
            }
    }
}

public extension View {
    func preparedArtworkSheet<Item: Hashable & Identifiable>(
        item: Binding<Item?>,
        artworkNames: @escaping (Item) -> [String],
        @ViewBuilder content: @escaping (Item) -> some View,
    ) -> some View {
        modifier(PreparedArtworkSheet(item: item, artworkNames: artworkNames, destination: content))
    }

    func preparingArtwork<Item: Hashable>(
        request: Binding<Item?>,
        presentation: Binding<Item?>,
        artworkNames: @escaping (Item) -> [String],
    ) -> some View {
        modifier(ArtworkPresentationPreparation(
            request: request,
            presentation: presentation,
            artworkNames: artworkNames,
        ))
    }
}
