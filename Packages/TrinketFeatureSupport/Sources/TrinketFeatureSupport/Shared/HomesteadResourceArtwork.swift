import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct HomesteadResourceArtwork: View {
    let resource: HomesteadResource

    public init(resource: HomesteadResource) {
        self.resource = resource
    }

    public var body: some View {
        if let art = ArtCatalog.resourceArtByID[resource.rawValue] {
            PreparedArtworkImage(art, displaySize: .full)
                .scaledToFit()
                .decorativePreparedArtwork()
        } else {
            GameIconImage(resource.icon)
                .trinketTypography(.button)
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}
