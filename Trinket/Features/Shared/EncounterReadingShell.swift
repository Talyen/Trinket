import SwiftUI
import TrinketDesignSystem

/// Shared art → copy → trailing content reading stack for Mystery / Shop encounters.
/// Session rules, offer grids, and CTAs stay at the call site.
struct EncounterReadingShell<Artwork: View, Copy: View, Content: View>: View {
    let artVisible: Bool
    let copyVisible: Bool
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let copy: () -> Copy
    @ViewBuilder let content: () -> Content

    var body: some View {
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

enum EncounterReadingEntrance {
    @MainActor
    static func present(
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
