import SwiftUI
import TrinketAppState
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport

@MainActor
struct CollectionCombatantDetailSheet: ViewModifier {
    @Environment(OptionsStore.self) private var options

    @Binding var selection: CombatantDetailContext?
    let zoomNamespace: Namespace.ID
    var issuesSignposts = false

    func body(content: Content) -> some View {
        content.sheet(item: $selection) { context in
            presentation(context: context)
        }
    }

    private func presentation(context: CombatantDetailContext) -> some View {
        NavigationStack {
            RosterCombatantDetailView(
                kind: context.kind,
                combatantID: context.combatantID,
                hapticsEnabled: options.hapticsEnabled,
                effectsVolume: options.effectsVolume,
            )
        }
        .navigationTransition(.zoom(sourceID: context.combatantID, in: zoomNamespace))
        .fullGameOfferHost()
        .trinketDetailSheet()
        .modifier(
            CollectionCombatantSheetSignposts(
                combatantID: context.combatantID,
                isActive: issuesSignposts,
            ),
        )
    }
}

private struct CollectionCombatantSheetSignposts: ViewModifier {
    let combatantID: String
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true,
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "collectionCombatant=\(combatantID)",
                    )
                }
        } else {
            content
        }
    }
}
