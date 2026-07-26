import CoreGraphics
import QuartzCore
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import UIKit

/// Prewarmed glyph store for combat feedback chips. Glyphs are baked white and
/// tinted at compose time so the atlas keys only on font face + scale.
@MainActor
final class CombatFeedbackGlyphAtlas {
    static let shared = CombatFeedbackGlyphAtlas()

    struct Face: Hashable {
        /// Two faces match the chip typography tiers (emphasis ≈34pt, normal ≈28pt).
        enum Typography: Hashable, CaseIterable {
            case emphasis
            case normal

            init(feedbackClass: CombatFeedbackClass) {
                switch feedbackClass {
                case .critical, .deathsDoor:
                    self = .emphasis
                case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
                    self = .normal
                }
            }

            var representativeClass: CombatFeedbackClass {
                switch self {
                case .emphasis: .critical
                case .normal: .heal
                }
            }
        }

        let typography: Typography
        let presentationRole: CombatFeedbackPresentationRole
        let dynamicTypeSize: DynamicTypeSize
        let displayScaleHundredths: Int

        init(
            feedbackClass: CombatFeedbackClass,
            presentationRole: CombatFeedbackPresentationRole = .headline,
            dynamicTypeSize: DynamicTypeSize,
            displayScaleHundredths: Int
        ) {
            typography = Typography(feedbackClass: feedbackClass)
            self.presentationRole = presentationRole
            self.dynamicTypeSize = dynamicTypeSize
            self.displayScaleHundredths = displayScaleHundredths
        }

        init(
            typography: Typography,
            presentationRole: CombatFeedbackPresentationRole = .headline,
            dynamicTypeSize: DynamicTypeSize,
            displayScaleHundredths: Int
        ) {
            self.typography = typography
            self.presentationRole = presentationRole
            self.dynamicTypeSize = dynamicTypeSize
            self.displayScaleHundredths = displayScaleHundredths
        }
    }

    /// Concurrency-Safety: `@unchecked Sendable` — `CGImage` bitmaps are immutable
    /// after rasterization; detached bake workers only create glyphs that the
    /// MainActor atlas then stores.
    struct Glyph: @unchecked Sendable {
        let image: CGImage
        let width: CGFloat
        let height: CGFloat
    }

    private var symbols: [SymbolKey: Glyph] = [:]
    private var fragments: [FragmentKey: Glyph] = [:]
    private var pendingPrewarmTask: Task<Void, Never>?

    struct SymbolKey: Hashable {
        let face: Face
        let symbolName: String
    }

    struct FragmentKey: Hashable {
        let face: Face
        let text: String
    }

    /// Concurrency-Safety: `@unchecked Sendable` — value payload for detached bake
    /// results; carries immutable `Glyph` bitmaps plus hashable keys back to the
    /// MainActor atlas merge.
    enum PreparedGlyph: @unchecked Sendable {
        case symbol(SymbolKey, Glyph)
        case fragment(FragmentKey, Glyph)
    }

    enum PrewarmRequest {
        case symbol(SymbolKey, CombatFeedbackChipStyle)
        case fragment(FragmentKey, CombatFeedbackChipStyle)
    }

    func removeAll() {
        pendingPrewarmTask?.cancel()
        pendingPrewarmTask = nil
        symbols.removeAll(keepingCapacity: true)
        fragments.removeAll(keepingCapacity: true)
    }

    func symbol(
        named symbolName: String,
        face: Face,
        recipe: CombatFeedbackChipStyle
    ) -> Glyph? {
        let key = SymbolKey(face: face, symbolName: symbolName)
        if let glyph = symbols[key] {
            return glyph
        }
        guard let glyph = Self.bakeSymbol(named: symbolName, face: face, recipe: recipe) else {
            return nil
        }
        symbols[key] = glyph
        return glyph
    }

    func fragment(
        _ text: String,
        face: Face,
        recipe: CombatFeedbackChipStyle
    ) -> Glyph? {
        let key = FragmentKey(face: face, text: text)
        if let glyph = fragments[key] {
            return glyph
        }
        guard let glyph = Self.bakeFragment(text, face: face, recipe: recipe) else {
            return nil
        }
        fragments[key] = glyph
        return glyph
    }

    /// Builds immutable atlas entries away from the main actor. UIKit/Core Graphics
    /// image renderers are safe for background bitmap construction; only the final
    /// dictionary publication returns to the actor that owns the battle-scoped cache.
    func prepareBattlePresentation(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        _ = startBattlePresentationPreparation(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    func prepareBattlePresentationAndWait(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        let task = startBattlePresentationPreparation(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        await task.value
    }

    private func startBattlePresentationPreparation(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> Task<Void, Never> {
        if let pendingPrewarmTask {
            return pendingPrewarmTask
        }
        let scale = max(1, displayScale)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let requests = prewarmRequests(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: scale
            )
            // Concurrency-Safety: detached CPU rasterization must not block
            // MainActor; results are immutable PreparedGlyph values merged here.
            let prepared = await Task.detached(priority: .utility) {
                Self.bake(requests)
            }.value
            guard !Task.isCancelled else { return }
            for glyph in prepared {
                switch glyph {
                case let .symbol(key, value):
                    symbols[key] = value
                case let .fragment(key, value):
                    fragments[key] = value
                }
            }
            pendingPrewarmTask = nil
        }
        pendingPrewarmTask = task
        return task
    }

    private func prewarmRequests(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> [PrewarmRequest] {
        let scaleHundredths = Int((displayScale * 100).rounded())
        let symbolNames = Set(Keyword.allCases.map(\.visualStyle.symbolName)).union([
            Keyword.VisualStyle.beneficialStatus.symbolName,
            Keyword.VisualStyle.negativeStatus.symbolName
        ])
        // Every integer label can be assembled from this complete alphabet. This is
        // both cheaper and more complete than eagerly rasterizing an arbitrary range.
        let numericFragments = CombatFeedbackChipLabel.numericAtlasFragments
        var requests: [PrewarmRequest] = []

        for typography in Face.Typography.allCases {
            let feedbackClass = typography.representativeClass
            let recipe = CombatFeedbackChipRecipes.chip(for: feedbackClass)
            for role in CombatFeedbackPresentationRole.allCases {
                let face = Face(
                    typography: typography,
                    presentationRole: role,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScaleHundredths: scaleHundredths
                )
                for symbolName in symbolNames {
                    let key = SymbolKey(face: face, symbolName: symbolName)
                    if symbols[key] == nil {
                        requests.append(.symbol(key, recipe))
                    }
                }
                for fragment in numericFragments {
                    let key = FragmentKey(face: face, text: fragment)
                    if fragments[key] == nil {
                        requests.append(.fragment(key, recipe))
                    }
                }
                // Word fragments stay headline-sized; secondary only shrinks numerics.
                if role == .headline {
                    for word in Self.wordAtlasCases(for: typography).compactMap(\.composeText) {
                        let key = FragmentKey(face: face, text: word)
                        if fragments[key] == nil {
                            requests.append(.fragment(key, recipe))
                        }
                    }
                }
            }
        }
        return requests
    }

    /// Short word fragments still drawn next to a keyword icon.
    /// Icon-only / dual-icon chips (dodge, Death's Door, cleanse, status, …) need
    /// no text fragments. Numerics use `numericAtlasFragments`.
    nonisolated static func wordAtlasCases(
        for typography: Face.Typography
    ) -> [CombatFeedbackChipWord] {
        switch typography {
        case .emphasis:
            // Death's Door is emphasis + symbol-only; no word fragment.
            []
        case .normal:
            CombatFeedbackChipWord.textAtlasCases.filter { word in
                switch word {
                case .critical:
                    false
                case .plain, .applied, .triggered:
                    true
                case .dodge, .cleanse, .purge, .halve, .status:
                    false
                }
            }
        }
    }

    nonisolated static func bake(_ requests: [PrewarmRequest]) -> [PreparedGlyph] {
        requests.compactMap { request in
            guard !Task.isCancelled else { return nil }
            switch request {
            case let .symbol(key, recipe):
                return bakeSymbol(named: key.symbolName, face: key.face, recipe: recipe)
                    .map { .symbol(key, $0) }
            case let .fragment(key, recipe):
                return bakeFragment(key.text, face: key.face, recipe: recipe)
                    .map { .fragment(key, $0) }
            }
        }
    }

    nonisolated static func bakeSymbol(
        named symbolName: String,
        face: Face,
        recipe: CombatFeedbackChipStyle
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            presentationRole: face.presentationRole,
            dynamicTypeSize: face.dynamicTypeSize
        )
        let config = UIImage.SymbolConfiguration(font: font)
        guard let image = UIImage(
            systemName: symbolName,
            withConfiguration: config
        )?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
            return nil
        }
        return rasterize(image: image, displayScaleHundredths: face.displayScaleHundredths)
    }

    nonisolated static func bakeFragment(
        _ text: String,
        face: Face,
        recipe: CombatFeedbackChipStyle
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            presentationRole: face.presentationRole,
            dynamicTypeSize: face.dynamicTypeSize
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let nsText = text as NSString
        let size = nsText.size(withAttributes: attributes)
        let height = max(size.height, font.lineHeight)
        let width = size.width
        guard width > 0 || text == "  " else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(face.displayScaleHundredths) / 100
        format.opaque = false
        let pointSize = CGSize(width: max(ceil(width), 1), height: ceil(height))
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let image = renderer.image { _ in
            if width > 0 {
                nsText.draw(at: .zero, withAttributes: attributes)
            }
        }
        guard let cgImage = image.cgImage else { return nil }
        return Glyph(image: cgImage, width: width > 0 ? pointSize.width : width, height: pointSize.height)
    }

    nonisolated static func rasterize(
        image: UIImage,
        displayScaleHundredths: Int
    ) -> Glyph? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(displayScaleHundredths) / 100
        format.opaque = false
        let pointSize = CGSize(width: ceil(size.width), height: ceil(size.height))
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pointSize))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return Glyph(image: cgImage, width: pointSize.width, height: pointSize.height)
    }
}

enum CombatFeedbackGlyphMetrics {
    static func uiFont(
        recipe: CombatFeedbackChipStyle,
        presentationRole: CombatFeedbackPresentationRole = .headline,
        dynamicTypeSize: DynamicTypeSize
    ) -> UIFont {
        let style: Font.TextStyle
        let weight: Font.Weight
        switch presentationRole {
        case .headline:
            style = recipe.textStyle
            weight = recipe.fontWeight
        case .secondary:
            style = .title2
            weight = .bold
        }
        let textStyle = uiTextStyle(style)
        let category = uiContentSizeCategory(dynamicTypeSize)
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let preferred = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let resolvedWeight = uiWeight(weight)
        let weighted = UIFont.systemFont(ofSize: preferred.pointSize, weight: resolvedWeight)
        let roundedDescriptor = weighted.fontDescriptor.withDesign(.rounded) ?? weighted.fontDescriptor
        let monospacedDescriptor = roundedDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
            ]]
        ])
        return UIFont(descriptor: monospacedDescriptor, size: preferred.pointSize)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .title3
        }
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .bold
        }
    }

    private static func uiContentSizeCategory(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// Shared display-link gate for paced prewarm (SFX-style).
@MainActor
enum CombatFeedbackDisplayLinkGate {
    static func waitForNextDisplayLink() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let link = CADisplayLink(
                target: DisplayLinkResumeBox(continuation: continuation),
                selector: #selector(DisplayLinkResumeBox.fire)
            )
            link.add(to: .main, forMode: .common)
            DisplayLinkResumeBox.retain(link)
        }
    }
}

@MainActor
private final class DisplayLinkResumeBox: NSObject {
    private static var retainedLinks: [ObjectIdentifier: CADisplayLink] = [:]

    private let continuation: CheckedContinuation<Void, Never>
    private var didResume = false

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    static func retain(_ link: CADisplayLink) {
        retainedLinks[ObjectIdentifier(link)] = link
    }

    @objc func fire(_ link: CADisplayLink) {
        guard !didResume else { return }
        didResume = true
        link.invalidate()
        Self.retainedLinks.removeValue(forKey: ObjectIdentifier(link))
        continuation.resume()
    }
}
