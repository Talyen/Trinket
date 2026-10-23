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

    let confirmHero: (String) -> SaveActionAttempt<Bool>
    let confirmCompanion: (String) -> SaveActionAttempt<Bool>
    let initialHeroID: String?

    init(
        initialSelection: StarterSelectionState,
        confirmHero: @escaping (String) -> SaveActionAttempt<Bool>,
        confirmCompanion: @escaping (String) -> SaveActionAttempt<Bool>,
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
                combatants: ContentAccessPolicy.freeFirst(GameContent.heroes),
                screenAccessibilityID: AccessibilityID.Onboarding.heroScreen,
                initialSelectionID: initialHeroID,
                onConfirm: confirmSelectedHero,
            )
            .navigationDestination(for: Destination.self) { _ in
                StarterRouletteScreen(
                    role: .companion,
                    combatants: ContentAccessPolicy.freeFirst(GameContent.companions),
                    screenAccessibilityID: AccessibilityID.Onboarding.companionScreen,
                    onConfirm: confirmSelectedCompanion,
                )
            }
        }
    }

    private func confirmSelectedHero(_ heroID: String) -> SaveActionAttempt<Bool> {
        confirmHero(heroID).map { committed in
            if committed, !path.contains(.companion) {
                path.append(.companion)
            }
            return committed
        }
    }

    private func confirmSelectedCompanion(_ companionID: String) -> SaveActionAttempt<Bool> {
        confirmCompanion(companionID)
    }
}
