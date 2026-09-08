import SwiftUI
import TrinketAppState
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadCollectionPreview: View {
    @Environment(ShellSession.self) private var shellSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    let amounts: [ResourceAmount]
    let isCollecting: Bool

    private var resources: [HomesteadResource] {
        HomesteadResource.allCases.filter { resource in
            amounts.contains { $0.resource == resource }
        }
    }

    private var isAnimating: Bool {
        isVisible && !isCollecting && scenePhase == .active
            && shellSession.selectedTab == .homestead && shellSession.homesteadPath.isEmpty
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(resources.indices)
            VStack(spacing: TrinketDesign.Spacing.small) {
                ForEach(Array(stride(from: 0, to: resources.count, by: 4)), id: \.self) { start in
                    row(start ..< min(start + 4, resources.count))
                }
            }
        }
        .padding(.top, HomesteadMotion.readyLift)
        .opacity(isCollecting ? 0 : 1)
        .onScrollVisibilityChange(threshold: 0.1) { isVisible = $0 }
        .onDisappear { isVisible = false }
    }

    private func row(_ indices: Range<Int>) -> some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            ForEach(indices, id: \.self) { index in
                let resource = resources[index]
                if isAnimating {
                    artwork(resource)
                        .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { content, lift in
                            content.offset(y: lift)
                        } keyframes: { _ in
                            if index == 0 {
                                MoveKeyframe(0)
                            } else {
                                LinearKeyframe(0, duration: Double(index) * HomesteadMotion.readyStagger)
                            }
                            CubicKeyframe(-HomesteadMotion.readyLift, duration: HomesteadMotion.readyRiseDuration)
                            SpringKeyframe(0, duration: HomesteadMotion.readyReturnDuration, spring: .smooth)
                            LinearKeyframe(
                                0,
                                duration: HomesteadMotion.readyRestDuration
                                    + Double(resources.count - index - 1) * HomesteadMotion.readyStagger,
                            )
                        }
                        .id(resources)
                } else {
                    artwork(resource)
                }
            }
        }
        .fixedSize()
    }

    private func artwork(_ resource: HomesteadResource) -> some View {
        HomesteadResourceArtwork(resource: resource)
            .frame(
                width: TrinketDesign.Layout.walletResourceArtworkSize,
                height: TrinketDesign.Layout.walletResourceArtworkSize,
            )
            .anchorPreference(key: HomesteadCollectionArtworkAnchors.self, value: .bounds) {
                [resource: $0]
            }
    }
}
