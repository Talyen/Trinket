import SwiftUI

enum LabyrinthMapMotion {
    static var selection: Animation {
        .spring(response: 0.22, dampingFraction: 1)
    }

    static var inspector: Animation {
        .spring(response: 0.32, dampingFraction: 0.9)
    }

    static var floorChange: Animation {
        .spring(response: 0.38, dampingFraction: 1)
    }
}
