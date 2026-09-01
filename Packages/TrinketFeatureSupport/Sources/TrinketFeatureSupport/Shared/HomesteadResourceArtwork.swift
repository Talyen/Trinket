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
            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .scaledToFit()
                .decorativePreparedArtwork()
        } else {
            Image(systemName: resource.symbolName)
                .trinketTypography(.button)
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}
