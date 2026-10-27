import Foundation

public extension StageEncounter {
    var contextualTitleResource: LocalizedStringResource? {
        if case .recruit = self {
            return L10n.authored_ab6cad13fab37b90
        }
        return nil
    }

    var contextualActionResource: LocalizedStringResource? {
        switch self {
        case .battle, .randomBattle: L10n.authored_fe80ab7e556ba1f8
        default: nil
        }
    }
}

public extension LabyrinthNodeType {
    var contextualTitleResource: LocalizedStringResource? {
        self == .recruit ? L10n.authored_85ea82a2b5a42590 : nil
    }
}
