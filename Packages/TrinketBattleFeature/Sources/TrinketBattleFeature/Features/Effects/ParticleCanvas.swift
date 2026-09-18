import CoreGraphics
import SwiftUI

/// Shared ellipse-particle stanza for the battle Canvas renderers. Sampling
/// math stays per effect (each works in its own coordinate space); only the
/// rect/context/opacity/fill sequence is shared, so pixels are unchanged.
extension GraphicsContext {
    func fillParticle(
        center: CGPoint,
        diameter: CGFloat,
        opacity: Double,
        color: Color,
    ) {
        guard opacity > 0, diameter > 0 else { return }
        var particleContext = self
        particleContext.opacity = opacity
        particleContext.fill(
            Path(ellipseIn: CGRect(
                x: center.x - diameter / 2,
                y: center.y - diameter / 2,
                width: diameter,
                height: diameter,
            )),
            with: .color(color),
        )
    }
}
