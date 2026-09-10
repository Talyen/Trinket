import SwiftUI
import TrinketDesignSystem

public struct EncounterReadingShell<Artwork: View, Copy: View, Content: View>: View {
    let artVisible: Bool
    let copyVisible: Bool
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let copy: () -> Copy
    @ViewBuilder let content: () -> Content

    public init(
        artVisible: Bool,
        copyVisible: Bool,
        @ViewBuilder artwork: @escaping () -> Artwork,
        @ViewBuilder copy: @escaping () -> Copy,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.artVisible = artVisible
        self.copyVisible = copyVisible
        self.artwork = artwork
        self.copy = copy
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Layout.contentMargin) {
                artwork()
                    .trinketPresentationVisibility(artVisible)
                    .scaleEffect(artVisible ? 1 : 0.94)

                copy()
                    .trinketPresentationVisibility(copyVisible)
                    .offset(y: copyVisible ? 0 : 8)

                content()
            }
            .padding(TrinketDesign.Spacing.extraLarge)
        }
    }
}

public enum EncounterReadingEntrance {
    @MainActor
    public static func present(
        artAppeared: Binding<Bool>,
        copyAppeared: Binding<Bool>,
        trailingAppeared: Binding<Bool>? = nil,
    ) async {
        withAnimation(TrinketMotion.Content.entrance) {
            artAppeared.wrappedValue = true
        }
        do {
            try await Task.sleep(for: .seconds(TrinketMotion.Content.entranceStagger))
            withAnimation(TrinketMotion.Content.entrance) {
                copyAppeared.wrappedValue = true
            }
            if let trailingAppeared {
                try await Task.sleep(for: .seconds(TrinketMotion.Content.secondEntranceDelay - TrinketMotion.Content.entranceStagger))
                withAnimation(TrinketMotion.Content.entrance) {
                    trailingAppeared.wrappedValue = true
                }
            }
        } catch {
            return
        }
    }
}
