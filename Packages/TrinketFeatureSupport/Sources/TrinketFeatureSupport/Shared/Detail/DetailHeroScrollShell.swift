import Observation
import SwiftUI
import TrinketContent
import TrinketDesignSystem

@MainActor
@Observable
final class HeroScrollState {
    var headerBaseHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight
    var headerContentHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight
    var headerTopInset: CGFloat = 0
    var titleOpacity: CGFloat = 0
    var overscroll: CGFloat = 0
}

public struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var heroContainerSize: CGSize?
    var primaryAction: DetailPrimaryAction?
    var hidesNavigationBar = false
    @ViewBuilder let header: (_ baseHeight: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    public init(
        title: String,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        heroContainerSize: CGSize? = nil,
        hidesNavigationBar: Bool = false,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat) -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent,
    ) {
        self.title = title
        self.heroHeightPolicy = heroHeightPolicy
        self.heroContainerSize = heroContainerSize
        self.hidesNavigationBar = hidesNavigationBar
        self.header = header
        self.bodyContent = bodyContent
    }

    @State private var scrollState = HeroScrollState()

    public var body: some View {
        navigationBarConfigured {
            ScrollView {
                VStack(spacing: 0) {
                    DetailHeroHeaderSection(
                        header: header,
                        scrollState: scrollState,
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        bodyContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let primaryAction {
                    DetailPrimaryActionFooter(primaryAction: primaryAction)
                }
            }
            .trinketScreenBackground()
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.always)
            .trinketSoftTopScrollEdge()
            .onScrollGeometryChange(for: HeroHeaderScrollMetrics.self) { geometry in
                let topInset = geometry.contentInsets.top
                let baseHeight = heroHeightPolicy.height(in: heroContainerSize ?? CGSize(
                    width: geometry.containerSize.width,
                    height: max(0, geometry.containerSize.height - topInset - geometry.contentInsets.bottom),
                ))
                let opacity = HeroHeaderLayout.titleOpacity(
                    offsetY: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height,
                    topInset: topInset,
                    bottomInset: geometry.contentInsets.bottom,
                    headerHeight: max(baseHeight, scrollState.headerContentHeight),
                )
                return HeroHeaderScrollMetrics(
                    baseHeight: baseHeight,
                    topInset: topInset,
                    titleOpacity: opacity,
                    // Include the top inset so artwork also covers space introduced by pinned navigation chrome.
                    overscroll: max(-geometry.contentOffset.y, 0),
                )
            } action: { _, metrics in
                if scrollState.headerBaseHeight != metrics.baseHeight {
                    scrollState.headerBaseHeight = metrics.baseHeight
                }
                if scrollState.headerTopInset != metrics.topInset {
                    scrollState.headerTopInset = metrics.topInset
                }
                if scrollState.titleOpacity != metrics.titleOpacity {
                    scrollState.titleOpacity = metrics.titleOpacity
                }
                if scrollState.overscroll != metrics.overscroll {
                    scrollState.overscroll = metrics.overscroll
                }
            }
        }
    }

    @ViewBuilder
    private func navigationBarConfigured(@ViewBuilder content: () -> some View) -> some View {
        if hidesNavigationBar {
            content()
                .toolbar(.hidden, for: .navigationBar)
        } else {
            content()
                .modifier(DetailHeroNavBarModifier(title: title, scrollState: scrollState))
        }
    }
}

private struct DetailHeroHeaderSection<Header: View>: View {
    let header: (_ baseHeight: CGFloat) -> Header
    let scrollState: HeroScrollState

    var body: some View {
        header(scrollState.headerBaseHeight)
            .environment(\.detailHeroScrollState, scrollState)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                scrollState.headerContentHeight = height
            }
    }
}

private struct DetailHeroNavBarModifier: ViewModifier {
    let title: String
    let scrollState: HeroScrollState

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .trinketToolbarBackgroundHidden {
                ToolbarItem(placement: .principal) {
                    DetailScrollNavigationTitle(
                        title: title,
                        scrollState: scrollState,
                    )
                }
            }
    }
}

extension EnvironmentValues {
    @Entry var detailHeroScrollState = nil as HeroScrollState?
}

private struct HeroHeaderScrollMetrics: Equatable {
    let baseHeight: CGFloat
    let topInset: CGFloat
    let titleOpacity: CGFloat
    let overscroll: CGFloat
}

private struct DetailScrollNavigationTitle: View {
    let title: String
    let scrollState: HeroScrollState

    var body: some View {
        let opacity = scrollState.titleOpacity
        // Keep the principal item's size stable as its visible title enters and leaves.
        GameLabel(title)
            .trinketTypography(.cardTitle)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                if opacity > 0 {
                    GameLabel(title)
                        .trinketTypography(.cardTitle)
                        .trinketPresentationVisibility(opacity >= 0.5, opacity: opacity)
                }
            }
    }
}

public struct DetailSection<Content: View>: View {
    let title: String
    var sectionID: String?
    @ViewBuilder let content: () -> Content

    public init(
        _ title: String,
        sectionID: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.sectionID = sectionID
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            GameLabel(title)
                .trinketTypography(.rowTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Layout.contentTopPadding)
                .accessibilityIdentifier(sectionID ?? title)

            content()
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        }
    }
}

/// Shared primary-action configuration for detail screens. Item and ability
/// detail previously carried twin private `Action` enums plus a separate
/// purchase struct to express the same shape: an optional footer button with
/// a computed title, an accessibility identifier, and a disabled state.
/// One value type keeps the two screens' footers identical by construction.
struct DetailPrimaryAction {
    let title: String
    var accessibilityIdentifier: String?
    var isDisabled: Bool = false
    var isCompact: Bool = false
    let action: () -> Void
}

struct DetailPrimaryActionFooter: View {
    let primaryAction: DetailPrimaryAction

    var body: some View {
        Group {
            if primaryAction.isCompact {
                HStack {
                    Spacer(minLength: 0)
                    button
                    Spacer(minLength: 0)
                }
            } else {
                button.trinketCenteredPrimaryAction()
            }
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .trinketSheetChromeIgnoresDismissDrag()
    }

    private var button: some View {
        Button(action: primaryAction.action) {
            GameLabel(primaryAction.title)
                .frame(minWidth: primaryAction.isCompact ? 96 : 0, maxWidth: primaryAction.isCompact ? nil : .infinity)
        }
        .trinketPrimaryActionButton(accessibilityIdentifier: primaryAction.accessibilityIdentifier ?? primaryAction.title)
        .disabled(primaryAction.isDisabled)
    }
}
