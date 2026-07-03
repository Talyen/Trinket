import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case battle = "Battle"

    var id: String {
        rawValue
    }

    var subtitle: String {
        switch self {
        case .battle:
            return "Choose a Hero and Pet, then test simple Keyword abilities against an enemy."
        }
    }
}
