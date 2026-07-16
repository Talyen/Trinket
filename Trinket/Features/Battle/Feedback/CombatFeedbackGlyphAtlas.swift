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
        let feedbackClass: CombatFeedbackClass
        let dynamicTypeSize: DynamicTypeSize
        let displayScaleHundredths: Int
    }

    struct Glyph {
        let image: CGImage
        let width: CGFloat
        let height: CGFloat
    }

    private var symbols: [SymbolKey: Glyph] = [:]
    private var fragments: [FragmentKey: Glyph] = [:]
    private var pendingPrewarmTask: Task<Void, Never>?

    private struct SymbolKey: Hashable {
        let face: Face
        let symbolName: String
    }

    private struct FragmentKey: Hashable {
        let face: Face
        let text: String
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
        recipe: CombatFeedbackMotionRecipe
    ) -> Glyph? {
        let key = SymbolKey(face: face, symbolName: symbolName)
        if let glyph = symbols[key] {
            return glyph
        }
        guard let glyph = bakeSymbol(named: symbolName, face: face, recipe: recipe) else {
            return nil
        }
        symbols[key] = glyph
        return glyph
    }

    func fragment(
        _ text: String,
        face: Face,
        recipe: CombatFeedbackMotionRecipe
    ) -> Glyph? {
        let key = FragmentKey(face: face, text: text)
        if let glyph = fragments[key] {
            return glyph
        }
        guard let glyph = bakeFragment(text, face: face, recipe: recipe) else {
            return nil
        }
        fragments[key] = glyph
        return glyph
    }

    /// Spreads atlas baking across display-link turns so Stage Select → Battle stays smooth.
    func prepareBattlePresentation(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        pendingPrewarmTask?.cancel()
        let scale = max(1, displayScale)
        pendingPrewarmTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await prewarmPaced(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: scale
            )
            pendingPrewarmTask = nil
        }
    }

    private func prewarmPaced(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        let scaleHundredths = Int((displayScale * 100).rounded())
        var workItems = 0
        let yieldEvery = 16

        func yieldIfNeeded() async {
            workItems += 1
            if workItems % yieldEvery == 0 {
                await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
            }
        }

        let symbolNames = Set(Keyword.allCases.map(\.visualStyle.symbolName))
        let wordStrings = CombatFeedbackChipWord.allAtlasCases.map(\.displayString)
        // Common combat amounts stay warm; rare values bake on first miss into the atlas.
        let commonAmounts = Array((-40 ... -1)) + Array(1 ... 30)
        let commonPercents = [5, 10, 15, 20, 25, 50]

        for feedbackClass in CombatFeedbackClass.allCases {
            guard !Task.isCancelled else { return }
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            let face = Face(
                feedbackClass: feedbackClass,
                dynamicTypeSize: dynamicTypeSize,
                displayScaleHundredths: scaleHundredths
            )
            for symbolName in symbolNames {
                _ = symbol(named: symbolName, face: face, recipe: recipe)
                await yieldIfNeeded()
                guard !Task.isCancelled else { return }
            }
            for amount in commonAmounts {
                _ = fragment(
                    CombatFeedbackChipLabel.formatAmount(amount),
                    face: face,
                    recipe: recipe
                )
                await yieldIfNeeded()
                guard !Task.isCancelled else { return }
            }
            for percent in commonPercents {
                _ = fragment(
                    CombatFeedbackChipLabel.formatPercent(percent),
                    face: face,
                    recipe: recipe
                )
                await yieldIfNeeded()
                guard !Task.isCancelled else { return }
            }
            for word in wordStrings {
                _ = fragment(word, face: face, recipe: recipe)
                await yieldIfNeeded()
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func bakeSymbol(
        named symbolName: String,
        face: Face,
        recipe: CombatFeedbackMotionRecipe
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
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

    private func bakeFragment(
        _ text: String,
        face: Face,
        recipe: CombatFeedbackMotionRecipe
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
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

    private func rasterize(
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
        recipe: CombatFeedbackMotionRecipe,
        dynamicTypeSize: DynamicTypeSize
    ) -> UIFont {
        let textStyle = uiTextStyle(recipe.textStyle)
        let category = uiContentSizeCategory(dynamicTypeSize)
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let preferred = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let weight = uiWeight(recipe.fontWeight)
        let weighted = UIFont.systemFont(ofSize: preferred.pointSize, weight: weight)
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
