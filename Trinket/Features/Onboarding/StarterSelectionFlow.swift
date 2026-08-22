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
    @State private var selectedHeroID: String?
    @State private var selectedCompanionID: String?

    let confirmHero: (String) -> Bool
    let confirmCompanion: (String) -> Bool

    init(
        initialSelection: StarterSelectionState,
        confirmHero: @escaping (String) -> Bool,
        confirmCompanion: @escaping (String) -> Bool
    ) {
        _path = State(initialValue: initialSelection.phase == .chooseCompanion ? [.companion] : [])
        _selectedHeroID = State(initialValue: initialSelection.heroID)
        self.confirmHero = confirmHero
        self.confirmCompanion = confirmCompanion
    }

    var body: some View {
        NavigationStack(path: $path) {
            StarterRouletteScreen(
                roleName: "Hero",
                combatants: GameContent.starterHeroes,
                screenAccessibilityID: AccessibilityID.Onboarding.heroScreen,
                onConfirm: confirmSelectedHero
            )
            .navigationDestination(for: Destination.self) { _ in
                StarterRouletteScreen(
                    roleName: "Companion",
                    combatants: GameContent.starterCompanions,
                    screenAccessibilityID: AccessibilityID.Onboarding.companionScreen,
                    onConfirm: confirmSelectedCompanion
                )
            }
        }
    }

    private func confirmSelectedHero(_ heroID: String) -> Bool {
        guard confirmHero(heroID) else { return false }
        selectedHeroID = heroID
        path.append(.companion)
        return true
    }

    private func confirmSelectedCompanion(_ companionID: String) -> Bool {
        guard confirmCompanion(companionID) else { return false }
        selectedCompanionID = companionID
        return true
    }
}
