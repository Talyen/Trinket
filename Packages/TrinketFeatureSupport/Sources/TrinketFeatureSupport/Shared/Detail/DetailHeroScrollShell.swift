import Observation
import SwiftUI
import TrinketContent
import TrinketDesignSystem

@MainActor
@Observable
private final class HeroScrollState {
    var headerBaseHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight
    var headerContentHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight
    var headerTopInset: CGFloat = 0
    var titleOpacity: CGFloat = 0
    var overscroll: CGFloat = 0
    var isPinned = false
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
            .modifier(DetailHeroSoftEdgeModifier(scrollState: scrollState))
            .onScrollGeometryChange(for: HeroHeaderScrollMetrics.self) { geometry in
                let topInset = geometry.contentInsets.top
                let baseHeight = heroHeightPolicy.height(in: heroContainerSize ?? CGSize(
                    width: geometry.containerSize.width,
                    height: max(0, geometry.containerSize.height - topInset - geometry.contentInsets.bottom),
                ))
                let threshold = max(baseHeight, scrollState.headerContentHeight) - topInset
                let offsetY = geometry.contentOffset.y + topInset
                let opacity = min(max((offsetY - threshold) / 32, 0), 1)
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
                let isPinned = metrics.titleOpacity >= 0.5
                if scrollState.isPinned != isPinned {
                    scrollState.isPinned = isPinned
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
            .environment(\.detailHeroOverscroll, scrollState.overscroll)
            .environment(\.detailHeroTopInset, scrollState.headerTopInset)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                scrollState.headerContentHeight = height
            }
    }
}

private struct DetailHeroSoftEdgeModifier: ViewModifier {
    let scrollState: HeroScrollState

    func body(content: Content) -> some View {
        content
            .trinketSoftTopScrollEdge(isHidden: !scrollState.isPinned)
    }
}

private struct DetailHeroNavBarModifier: ViewModifier {
    @Environment(\.locale) private var locale
    let title: String
    let scrollState: HeroScrollState

    func body(content: Content) -> some View {
        content
            .navigationTitle(scrollState.isPinned ? ContentCopy.localized(title, locale: locale) : "")
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
    /// Scroll geometry keeps updating even when the hero artwork is offscreen.
    @Entry var detailHeroOverscroll: CGFloat = 0
    @Entry var detailHeroTopInset: CGFloat = 0
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
        if opacity > 0 {
            GameLabel(title)
                .trinketTypography(.cardTitle)
                .trinketPresentationVisibility(opacity >= 0.5, opacity: opacity)
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
    let action: () -> Void
}

struct DetailPrimaryActionFooter: View {
    let primaryAction: DetailPrimaryAction

    var body: some View {
        Button(action: primaryAction.action) {
            GameLabel(primaryAction.title)
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(accessibilityIdentifier: primaryAction.accessibilityIdentifier ?? primaryAction.title)
        .trinketCenteredPrimaryAction()
        .disabled(primaryAction.isDisabled)
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .trinketSheetChromeIgnoresDismissDrag()
    }
}
