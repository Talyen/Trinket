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
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.artVisible = artVisible
        self.copyVisible = copyVisible
        self.artwork = artwork
        self.copy = copy
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                artwork()
                    .opacity(artVisible ? 1 : 0)
                    .scaleEffect(artVisible ? 1 : 0.94)

                copy()
                    .opacity(copyVisible ? 1 : 0)
                    .offset(y: copyVisible ? 0 : 8)

                content()
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}

public enum EncounterReadingEntrance {
    @MainActor
    public static func present(
        artAppeared: Binding<Bool>,
        copyAppeared: Binding<Bool>,
        trailingAppeared: Binding<Bool>? = nil
    ) {
        withAnimation(TrinketMotion.Content.entrance) {
            artAppeared.wrappedValue = true
        }
        withAnimation(TrinketMotion.Content.entrance.delay(TrinketMotion.Content.entranceStagger)) {
            copyAppeared.wrappedValue = true
        }
        if let trailingAppeared {
            withAnimation(
                TrinketMotion.Content.entrance.delay(TrinketMotion.Content.secondEntranceDelay)
            ) {
                trailingAppeared.wrappedValue = true
            }
        }
    }
}
