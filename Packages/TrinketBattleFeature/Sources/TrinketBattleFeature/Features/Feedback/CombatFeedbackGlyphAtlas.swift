import CoreGraphics
import QuartzCore
import SwiftUI
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

    private(set) var icons: [IconKey: Glyph] = [:]
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

    struct IconKey: Hashable {
        let face: Face
        let icon: GameIcon
    }

    struct FragmentKey: Hashable {
        let face: Face
        let text: String
    }

    /// Concurrency-Safety: `@unchecked Sendable` — value payload for detached bake
    enum PreparedGlyph: @unchecked Sendable {
        case icon(IconKey, Glyph)
        case fragment(FragmentKey, Glyph)
    }

    enum PrewarmRequest {
        case icon(IconKey, CombatFeedbackChipStyle)
        case fragment(FragmentKey, CombatFeedbackChipStyle)
    }

    func removeAll() {
        prewarmGeneration &+= 1
        pendingPrewarm?.task.cancel()
        pendingPrewarm = nil
        preparedPresentationKeys.removeAll(keepingCapacity: true)
        icons.removeAll(keepingCapacity: true)
        fragments.removeAll(keepingCapacity: true)
    }

    func icon(
        _ icon: GameIcon,
        face: Face,
        recipe: CombatFeedbackChipStyle,
    ) -> Glyph? {
        let key = IconKey(face: face, icon: icon)
        if let glyph = icons[key] {
            return glyph
        }
        guard let glyph = Self.bakeIcon(icon, face: face, recipe: recipe) else {
            return nil
        }
        icons[key] = glyph
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
                case let .icon(key, value):
                    icons[key] = value
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
        let requiredIcons = Set(Keyword.allCases.map { CombatFeedbackChipPresentation.Style.keyword($0).feedbackIcon }).union([
            CombatFeedbackChipPresentation.Style.beneficialStatus.feedbackIcon,
            CombatFeedbackChipPresentation.Style.negativeStatus.feedbackIcon,
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
                for icon in requiredIcons {
                    let key = IconKey(face: face, icon: icon)
                    if icons[key] == nil {
                        requests.append(.icon(key, recipe))
                    }
                }
                for fragment in numericFragments {
                    let key = FragmentKey(face: face, text: fragment)
                    if fragments[key] == nil {
                        requests.append(.fragment(key, recipe))
                    }
                }
                for fragment in Self.wordAtlasFragments(for: typography) {
                    let key = FragmentKey(face: face, text: fragment)
                    if fragments[key] == nil {
                        requests.append(.fragment(key, recipe))
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
            case let .icon(key, recipe):
                return bakeIcon(key.icon, face: key.face, recipe: recipe)
                    .map { .icon(key, $0) }
            case let .fragment(key, recipe):
                return bakeFragment(key.text, face: key.face, recipe: recipe)
                    .map { .fragment(key, $0) }
            }
        }
    }

    nonisolated static func bakeIcon(
        _ icon: GameIcon,
        face: Face,
        recipe: CombatFeedbackChipStyle,
    ) -> Glyph? {
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            presentationRole: face.presentationRole,
        )
        if let resource = icon.imageResource {
            let image = UIImage(resource: resource).withTintColor(.white, renderingMode: .alwaysOriginal)
            return rasterize(
                image: image,
                displayScaleHundredths: face.displayScaleHundredths,
                targetHeight: font.pointSize,
            )
        }
        guard case let .system(name) = icon,
              let image = UIImage(
                  systemName: name,
                  withConfiguration: UIImage.SymbolConfiguration(font: font),
              )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        else { return nil }
        return rasterize(image: image, displayScaleHundredths: face.displayScaleHundredths)
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
        targetHeight: CGFloat? = nil,
    ) -> Glyph? {
        let imageScale = targetHeight.map { $0 / max(1, image.size.height) } ?? 1
        let size = CGSize(width: image.size.width * imageScale, height: image.size.height * imageScale)
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
