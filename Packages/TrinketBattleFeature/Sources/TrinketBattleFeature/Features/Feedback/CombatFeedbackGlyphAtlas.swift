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
        let displayScaleHundredths: Int
    }

    enum Content: Hashable {
        case icon(GameIcon)
        case fragment(String)
    }

    struct Key: Hashable {
        let face: Face
        let content: Content
    }

    /// Concurrency-Safety: `@unchecked Sendable` — `CGImage` bitmaps are immutable
    struct Glyph: @unchecked Sendable {
        let image: CGImage
        let width: CGFloat
        let height: CGFloat
    }

    private(set) var glyphs: [Key: Glyph] = [:]
    private var maximumDigitWidths: [Face: CGFloat] = [:]
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

    func removeAll() {
        prewarmGeneration &+= 1
        pendingPrewarm?.task.cancel()
        pendingPrewarm = nil
        preparedPresentationKeys.removeAll(keepingCapacity: true)
        glyphs.removeAll(keepingCapacity: true)
        maximumDigitWidths.removeAll(keepingCapacity: true)
    }

    func glyph(_ content: Content, face: Face) -> Glyph? {
        let key = Key(face: face, content: content)
        if let cached = glyphs[key] {
            return cached
        }
        guard let glyph = Self.bake(key, font: CombatFeedbackGlyphMetrics.uiFont(typography: face.typography)) else { return nil }
        glyphs[key] = glyph
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

    func maximumDigitWidth(face: Face) -> CGFloat {
        if let width = maximumDigitWidths[face] {
            return width
        }
        let widths = (0 ... 9).compactMap {
            glyph(.fragment(String($0)), face: face)?.width
        }
        let width = widths.max() ?? 0
        // A failed glyph bake remains retryable instead of caching a partial metric.
        if widths.count == 10 {
            maximumDigitWidths[face] = width
        }
        return width
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
            for (key, glyph) in prepared {
                glyphs[key] = glyph
            }
            preparedPresentationKeys.insert(key)
            return key
        }
        pendingPrewarm = PendingPrewarm(generation: generation, task: task)
        return task
    }

    private func prewarmRequests(
        displayScaleHundredths: Int,
    ) -> [Key] {
        // Scope icons to closed-vocabulary appearances instead of every
        // Keyword: damage numerals are unbounded and never prewarmed, and
        // keywords that resolve to the same appearance share one icon.
        var requiredIcons: Set<GameIcon> = [
            CombatFeedbackChipPresentation.Style.beneficialStatus.feedbackIcon,
            CombatFeedbackChipPresentation.Style.negativeStatus.feedbackIcon,
        ]
        for appearance in CombatFeedbackClosedVocabulary.appearances {
            let presentation = appearance.presentation
            requiredIcons.insert(presentation.trailingStyle.feedbackIcon)
            if let leading = presentation.leadingStyle {
                requiredIcons.insert(leading.feedbackIcon)
            }
        }
        let numericFragments = CombatFeedbackChipLabel.numericAtlasFragments
        let contents = requiredIcons.map(Content.icon) + numericFragments.map(Content.fragment)
        var requests: [Key] = []

        for typography in CombatFeedbackTypographyTier.allCases {
            let face = Face(
                typography: typography,
                displayScaleHundredths: displayScaleHundredths,
            )
            for content in contents {
                let key = Key(face: face, content: content)
                if glyphs[key] == nil {
                    requests.append(key)
                }
            }
        }
        return requests
    }

    nonisolated static func bake(_ requests: [Key]) -> [(Key, Glyph)] {
        // Fonts depend on typography, not the icon/number or raster scale. Reuse within this worker batch.
        var fonts: [CombatFeedbackTypographyTier: UIFont] = [:]
        return requests.compactMap { key in
            guard !Task.isCancelled else { return nil }
            return autoreleasepool {
                let font = fonts[key.face.typography] ?? CombatFeedbackGlyphMetrics.uiFont(typography: key.face.typography)
                fonts[key.face.typography] = font
                return bake(key, font: font).map { (key, $0) }
            }
        }
    }

    private nonisolated static func bake(_ key: Key, font: UIFont) -> Glyph? {
        switch key.content {
        case let .icon(icon): bakeIcon(icon, face: key.face, font: font)
        case let .fragment(text): bakeFragment(text, face: key.face, font: font)
        }
    }

    private nonisolated static func bakeIcon(_ icon: GameIcon, face: Face, font: UIFont) -> Glyph? {
        guard let image = UIImage(
            systemName: icon.symbolName,
            withConfiguration: UIImage.SymbolConfiguration(font: font),
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        else { return nil }
        return rasterize(image: image, displayScaleHundredths: face.displayScaleHundredths)
    }

    private nonisolated static func renderedImage(
        pointSize: CGSize,
        displayScaleHundredths: Int,
        draw: (CGRect) -> Void,
    ) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(displayScaleHundredths) / 100
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        return renderer.image { _ in
            draw(CGRect(origin: .zero, size: pointSize))
        }.cgImage
    }

    private nonisolated static func bakeFragment(_ text: String, face: Face, font: UIFont) -> Glyph? {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        let nsText = text as NSString
        let size = nsText.size(withAttributes: attributes)
        let height = max(size.height, font.lineHeight)
        let width = size.width
        guard width > 0 || text == "  " else { return nil }

        let pointSize = CGSize(width: max(ceil(width), 1), height: ceil(height))
        guard let cgImage = renderedImage(
            pointSize: pointSize,
            displayScaleHundredths: face.displayScaleHundredths,
            draw: { _ in
                if width > 0 {
                    nsText.draw(at: .zero, withAttributes: attributes)
                }
            },
        ) else { return nil }
        return Glyph(image: cgImage, width: width > 0 ? pointSize.width : width, height: pointSize.height)
    }

    nonisolated static func rasterize(
        image: UIImage,
        displayScaleHundredths: Int,
    ) -> Glyph? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let pointSize = CGSize(width: ceil(size.width), height: ceil(size.height))
        guard let cgImage = renderedImage(
            pointSize: pointSize,
            displayScaleHundredths: displayScaleHundredths,
            draw: { rect in
                image.draw(in: rect)
            },
        ) else { return nil }
        return Glyph(image: cgImage, width: pointSize.width, height: pointSize.height)
    }
}

enum CombatFeedbackGlyphMetrics {
    static func uiFont(
        typography: CombatFeedbackTypographyTier,
    ) -> UIFont {
        let textStyle: UIFont.TextStyle = typography == .emphasis ? .largeTitle : .title1
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let preferred = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let pointSize = preferred.pointSize * 0.90
        let resolvedWeight: UIFont.Weight = typography == .emphasis ? .heavy : .bold
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
}
