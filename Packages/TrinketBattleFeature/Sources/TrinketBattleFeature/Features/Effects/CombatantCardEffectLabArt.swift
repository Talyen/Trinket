import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

/// Loads combatant art from the prepared cache, any loaded bundle, or the
/// workspace Assets.xcassets HEIC files (package previews lack the app catalog).
struct LabCombatantPortrait: View {
    let combatant: Combatant
    let size: CGSize

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(TrinketDesign.cardShape)
        .task(id: combatant.id) {
            image = LabCombatantArtLoader.image(for: combatant)
            if image == nil, let name = combatant.artReference?.imageName {
                await PreparedArtworkCache.shared.prepareAndPin(names: [name])
                image = LabCombatantArtLoader.image(for: combatant)
            }
        }
    }

    private var placeholder: some View {
        let style: TrinketDesign.CardPlaceholderStyle = switch combatant.role {
        case .hero: .hero
        case .companion: .companion
        case .enemy: .enemy
        }
        return ZStack {
            style.color.opacity(0.22)
            VStack(spacing: 6) {
                Image(systemName: style.symbolName)
                    .font(.system(size: min(size.width, size.height) * 0.22, weight: .semibold))
                    .foregroundStyle(style.color)
                    .symbolRenderingMode(.hierarchical)
                Text(combatant.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

@MainActor
enum LabCombatantArtLoader {
    static func image(for combatant: Combatant) -> UIImage? {
        guard let name = combatant.artReference?.imageName else { return nil }
        if let cached = PreparedArtworkCache.shared.image(named: name) {
            return cached
        }
        return loadUIImage(named: name)
    }

    static func loadUIImage(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
            return image
        }
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }
        if let appBundle = Bundle.allBundles.first(where: {
            $0.bundleIdentifier == "com.ryanmcintire.Trinket"
        }), let image = UIImage(named: name, in: appBundle, compatibleWith: nil) {
            return image
        }
        // Package previews often lack the app asset catalog — load authored HEIC
        // directly from the workspace Assets.xcassets via this source file's path.
        return loadWorkspaceAsset(named: name)
    }

    private static func loadWorkspaceAsset(named name: String) -> UIImage? {
        guard let repoRoot = repositoryRootPath() else { return nil }
        let heicURL = URL(fileURLWithPath: repoRoot)
            .appendingPathComponent("Trinket/Assets.xcassets")
            .appendingPathComponent("\(name).imageset")
            .appendingPathComponent("\(name).heic")
        guard FileManager.default.fileExists(atPath: heicURL.path),
              let data = try? Data(contentsOf: heicURL),
              let image = UIImage(data: data)
        else {
            return nil
        }
        return image
    }

    private static func repositoryRootPath() -> String? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 8 {
            url.deleteLastPathComponent()
            let assets = url.appendingPathComponent("Trinket/Assets.xcassets")
            if FileManager.default.fileExists(atPath: assets.path) {
                return url.path
            }
        }
        return nil
    }
}
#endif
