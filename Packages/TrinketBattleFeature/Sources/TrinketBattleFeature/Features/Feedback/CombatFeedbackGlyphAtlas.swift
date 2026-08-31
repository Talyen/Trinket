import CoreGraphics
import QuartzCore
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

@MainActor
final class CombatFeedbackGlyphAtlas {
    static let shared = CombatFeedbackGlyphAtlas()

    struct Face: Hashable {
        let typography: CombatFeedbackTypographyTier
        let presentationRole: CombatFeedbackPresentationRole
        let displayScaleHundredths: Int

        init(
            feedbackClass: CombatFeedbackClass,
            presentationRole: CombatFeedbackPresentationRole = .headline,
            displayScaleHundredths: Int,
        ) {
            typography = feedbackClass.typographyTier
            self.presentationRole = presentationRole
            self.displayScaleHundredths = displayScaleHundredths
        }

        init(
            typography: CombatFeedbackTypographyTier,
            presentationRole: CombatFeedbackPresentationRole = .headline,
            displayScaleHundredths: Int,
        ) {
            self.typography = typography
            self.presentationRole = presentationRole
            self.displayScaleHundredths = displayScaleHundredths
        }
    }

    /// Concurrency-Safety: `@unchecked Sendable` — `CGImage` bitmaps are immutable
    struct Glyph: @unchecked Sendable {
        let image: CGImage
        let width: CGFloat
        let height: CGFloat
    }

    private var symbols: [SymbolKey: Glyph] = [:]
    private var fragments: [FragmentKey: Glyph] = [:]
    private var preparedPresentationKeys: Set<PresentationKey> = []
    private var pendingPrewarm: PendingPrewarm?
    private var prewarmGeneration = 0

    struct PresentationKey: Hashable {
        let displayScaleHundredths: Int

        init(displayScale: CGFloat) {
            displayScaleHundredths = Int((max(1, displayScale) * 100).rounded())
        }
    }

    private struct PendingPrewarm {
        let generation: Int
        let task: Task<PresentationKey?, Never>
    }

    struct SymbolKey: Hashable {
        let face: Face
        let symbolName: String
    }

    struct FragmentKey: Hashable {
        let face: Face
        let text: String
    }

    /// Concurrency-Safety: `@unchecked Sendable` — value payload for detached bake
    enum PreparedGlyph: @unchecked Sendable {
        case symbol(SymbolKey, Glyph)
        case fragment(FragmentKey, Glyph)
    }

    enum PrewarmRequest {
        case symbol(SymbolKey, CombatFeedbackChipStyle)
        case fragment(FragmentKey, CombatFeedbackChipStyle)
    }

    func removeAll() {
        prewarmGeneration &+= 1
        pendingPrewarm?.task.cancel()
        pendingPrewarm = nil
        preparedPresentationKeys.removeAll(keepingCapacity: true)
        symbols.removeAll(keepingCapacity: true)
        fragments.removeAll(keepingCapacity: true)
    }

    func symbol(
        named symbolName: String,
        face: Face,
        recipe: CombatFeedbackChipStyle,
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
        recipe: CombatFeedbackChipStyle,
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

    func prepareBattlePresentationAndWait(
        displayScale: CGFloat,
    ) async {
        let key = PresentationKey(displayScale: displayScale)
        while !preparedPresentationKeys.contains(key) {
            let completedKey = if let pendingPrewarm {
                await pendingPrewarm.task.value
            } else {
                await startBattlePresentationPreparation(for: key).value
            }
            guard !Task.isCancelled, completedKey != nil else { return }
        }
    }

    private func startBattlePresentationPreparation(
        for key: PresentationKey,
    ) -> Task<PresentationKey?, Never> {
        prewarmGeneration &+= 1
        let generation = prewarmGeneration
        let task: Task<PresentationKey?, Never> = Task { @MainActor [weak self] in
            guard let self else { return nil }
            defer {
                if pendingPrewarm?.generation == generation {
                    pendingPrewarm = nil
                }
            }
            let requests = prewarmRequests(displayScaleHundredths: key.displayScaleHundredths)
            // Concurrency-Safety: detached CPU rasterization must not block
            let worker = Task.detached(priority: .utility) {
                Self.bake(requests)
            }
            let prepared = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, prewarmGeneration == generation else { return nil }
            for glyph in prepared {
                switch glyph {
                case let .symbol(key, value):
                    symbols[key] = value
                case let .fragment(key, value):
                    fragments[key] = value
                }
            }
            preparedPresentationKeys.insert(key)
            return key
        }
        pendingPrewarm = PendingPrewarm(generation: generation, task: task)
        return task
    }

    private func prewarmRequests(
        displayScaleHundredths: Int,
    ) -> [PrewarmRequest] {
        let symbolNames = Set(Keyword.allCases.map(\.visualStyle.symbolName)).union([
            Keyword.VisualStyle.beneficialStatus.symbolName,
            Keyword.VisualStyle.negativeStatus.symbolName,
        ])
        let numericFragments = CombatFeedbackChipLabel.numericAtlasFragments
        var requests: [PrewarmRequest] = []

        for typography in CombatFeedbackTypographyTier.allCases {
            let recipe = CombatFeedbackChipStyle.forClass(typography.representativeClass)
            for role in CombatFeedbackPresentationRole.allCases {
                let face = Face(
                    typography: typography,
                    presentationRole: role,
                    displayScaleHundredths: displayScaleHundredths,
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
                if role == .headline {
                    for fragment in Self.wordAtlasFragments(for: typography) {
                        let key = FragmentKey(face: face, text: fragment)
                        if fragments[key] == nil {
                            requests.append(.fragment(key, recipe))
                        }
                    }
                }
            }
        }
        return requests
    }

    nonisolated static func wordAtlasFragments(
        for typography: CombatFeedbackTypographyTier,
    ) -> [String] {
        CombatFeedbackRasterCatalog.wordAtlasFragments(for: typography)
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
        recipe: CombatFeedbackChipStyle,
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            presentationRole: face.presentationRole,
        )
        if symbolName == Keyword.gold.visualStyle.symbolName,
           let goldImage = goldArtworkImage(targetHeight: font.lineHeight) {
            return rasterize(image: goldImage, displayScaleHundredths: face.displayScaleHundredths)
        }
        let config = UIImage.SymbolConfiguration(font: font)
        guard let image = UIImage(
            systemName: symbolName,
            withConfiguration: config,
        )?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
            return nil
        }
        return rasterize(image: image, displayScaleHundredths: face.displayScaleHundredths)
    }

    nonisolated private static func goldArtworkImage(targetHeight: CGFloat) -> UIImage? {
        let imageName = ArtCatalog.resourceArtByID[HomesteadResource.gold.rawValue]?.imageName
            ?? "resource_homestead_gold"
        guard let base = UIImage(named: imageName, in: .main, compatibleWith: nil)
            ?? UIImage(named: imageName)
        else {
            return nil
        }
        let height = max(1, targetHeight)
        let scale = height / max(1, base.size.height)
        let width = base.size.width * scale
        let size = CGSize(width: ceil(width), height: ceil(height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.withTintColor(.white, renderingMode: .alwaysOriginal)
    }

    nonisolated static func bakeFragment(
        _ text: String,
        face: Face,
        recipe: CombatFeedbackChipStyle,
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            presentationRole: face.presentationRole,
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
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
        displayScaleHundredths: Int,
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

private extension CombatFeedbackTypographyTier {
    var representativeClass: CombatFeedbackClass {
        switch self {
        case .emphasis: .critical
        case .normal: .heal
        }
    }
}

enum CombatFeedbackGlyphMetrics {
    static func uiFont(
        recipe: CombatFeedbackChipStyle,
        presentationRole: CombatFeedbackPresentationRole = .headline,
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
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let preferred = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let pointSize = preferred.pointSize * 0.90
        let resolvedWeight = uiWeight(weight)
        let weighted = UIFont.systemFont(ofSize: pointSize, weight: resolvedWeight)
        let roundedDescriptor = weighted.fontDescriptor.withDesign(.rounded) ?? weighted.fontDescriptor
        let monospacedDescriptor = roundedDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
            ]],
        ])
        return UIFont(descriptor: monospacedDescriptor, size: pointSize)
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
}

@MainActor
enum CombatFeedbackDisplayLinkGate {
    static func waitForNextDisplayLink() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let link = CADisplayLink(
                target: DisplayLinkResumeBox(continuation: continuation),
                selector: #selector(DisplayLinkResumeBox.fire),
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
