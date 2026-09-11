import SwiftUI

struct HiddenTabPrewarm: View {
    private enum Surface: CaseIterable, Hashable {
        case collection, homestead, options
    }

    @State private var laidOutSurfaces: Set<Surface> = []
    var onFirstLayout: () -> Void = {}

    var body: some View {
        ZStack {
            NavigationStack {
                CollectionView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.collection, hasLayout: hasLayout)
                    }
            }
            NavigationStack {
                HomesteadView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.homestead, hasLayout: hasLayout)
                    }
            }
            NavigationStack {
                OptionsView()
                    .onGeometryChange(for: Bool.self) { geometry in
                        geometry.size.width > 0 && geometry.size.height > 0
                    } action: { hasLayout in
                        acknowledgeLayout(.options, hasLayout: hasLayout)
                    }
            }
        }
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func acknowledgeLayout(_ surface: Surface, hasLayout: Bool) {
        guard hasLayout, laidOutSurfaces.insert(surface).inserted else { return }
        if laidOutSurfaces.count == Surface.allCases.count {
            onFirstLayout()
        }
    }
}
