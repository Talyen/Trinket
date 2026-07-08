import SwiftUI

enum DesignAssetColors {
    static func named(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}
