import SwiftUI

struct LockedCardEffectModifier: ViewModifier {
    let isLocked: Bool
    let cornerRadius: CGFloat

    @ScaledMetric(relativeTo: .body)
    private var lockIconSize: CGFloat = 34

    private static let lockedBlurRadius: CGFloat = 1
    private static let lockedSaturation: Double = 0.35

    init(isLocked: Bool, cornerRadius: CGFloat = TrinketDesign.Corners.card) {
        self.isLocked = isLocked
        self.cornerRadius = cornerRadius
    }

    private var clipShape: RoundedRectangle {
        TrinketDesign.shape(cornerRadius: cornerRadius)
    }

    func body(content: Content) -> some View {
        if isLocked {
            content
                .saturation(Self.lockedSaturation)
                .compositingGroup()
                .blur(radius: Self.lockedBlurRadius)
                .clipShape(clipShape)
                .disabled(true)
                .accessibilityLabel("Locked")
                .overlay { lockBadgeOverlay }
        } else {
            content
        }
    }

    private var lockBadgeOverlay: some View {
        let ink = TrinketDesign.Colors.Overlay.ink
        return Image(systemName: "lock.fill")
            .accessibilityHidden(true)
            .font(.system(size: lockIconSize))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .shadow(color: ink.opacity(0.9), radius: 1.5)
            .shadow(color: ink.opacity(0.55), radius: 3, x: 0, y: 1.5)
    }
}

struct CardLabelSpaceModifier: ViewModifier {
    let isReserved: Bool

    @ScaledMetric(relativeTo: .subheadline)
    private var reservedHeight: CGFloat = TrinketDesign.Layout.cardLabelReservedHeight

    func body(content: Content) -> some View {
        if isReserved {
            content.frame(minHeight: reservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

public extension View {
    func trinketArtworkPickerSelectionBorder(
        isSelected: Bool,
        color: Color = TrinketDesign.Colors.accent,
        lineWidth: CGFloat = 3,
    ) -> some View {
        overlay {
            TrinketDesign.cardShape.strokeBorder(color.opacity(isSelected ? 1 : 0), lineWidth: lineWidth)
        }
    }

    /// Card-identity surface. `trinketSurface(.card)` is the canonical base;
    /// this adds the artwork clip and subtle stroke when `showsStroke` is set.
    @ViewBuilder
    func trinketCardSurface(cornerRadius: CGFloat = TrinketDesign.Corners.card, showsStroke: Bool = false) -> some View {
        if showsStroke {
            let shape = TrinketDesign.shape(cornerRadius: cornerRadius)
            trinketSurface(.card, cornerRadiusOverride: cornerRadius)
                .clipShape(shape)
                .overlay { shape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1) }
        } else {
            trinketSurface(.card, cornerRadiusOverride: cornerRadius)
        }
    }

    func trinketLockedCardEffect(isLocked: Bool, cornerRadius: CGFloat = TrinketDesign.Corners.card) -> some View {
        modifier(LockedCardEffectModifier(isLocked: isLocked, cornerRadius: cornerRadius))
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }
}
