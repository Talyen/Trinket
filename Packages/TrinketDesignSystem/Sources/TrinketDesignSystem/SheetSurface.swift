import SwiftUI

extension EnvironmentValues {
    @Entry var trinketCanvasColor: Color = TrinketDesign.Colors.canvas
}

public extension View {
    /// Sheet bodies and artwork fades share one surface; full-screen canvases keep their own tone.
    func trinketSheetSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(TrinketDesign.Colors.sheet.ignoresSafeArea())
            .presentationBackground(TrinketDesign.Colors.sheet)
            .environment(\.trinketCanvasColor, TrinketDesign.Colors.sheet)
    }
}
