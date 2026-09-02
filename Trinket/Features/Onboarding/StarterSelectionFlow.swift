import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

struct StarterSelectionFlow: View {
    private enum Destination: Hashable {
        case companion
    }

    @State private var path: [Destination]

    let confirmHero: (String) -> Bool
    let confirmCompanion: (String) -> Bool
    let initialHeroID: String?

    init(
        initialSelection: StarterSelectionState,
        confirmHero: @escaping (String) -> Bool,
        confirmCompanion: @escaping (String) -> Bool,
    ) {
        _path = State(initialValue: initialSelection.phase == .chooseCompanion ? [.companion] : [])
        initialHeroID = initialSelection.heroID
        self.confirmHero = confirmHero
        self.confirmCompanion = confirmCompanion
    }

    var body: some View {
        NavigationStack(path: $path) {
            StarterRouletteScreen(
                role: .hero,
                combatants: GameContent.heroes,
                screenAccessibilityID: AccessibilityID.Onboarding.heroScreen,
                initialSelectionID: initialHeroID,
                onConfirm: confirmSelectedHero,
            )
            .navigationDestination(for: Destination.self) { _ in
                StarterRouletteScreen(
                    role: .companion,
                    combatants: GameContent.companions,
                    screenAccessibilityID: AccessibilityID.Onboarding.companionScreen,
                    onConfirm: confirmSelectedCompanion,
                )
            }
        }
    }

    private func confirmSelectedHero(_ heroID: String) -> Bool {
        guard confirmHero(heroID) else { return false }
        path.append(.companion)
        return true
    }

    private func confirmSelectedCompanion(_ companionID: String) -> Bool {
        confirmCompanion(companionID)
    }
}
