import Observation
import SwiftUI
import TrinketDesignSystem

/// Shared scroll + toolbar chrome for full-bleed hero detail sheets (combatants, items).
public struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var hidesNavigationBar = false
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    @State private var scrollPresentation = DetailScrollPresentationModel()
    @State private var showsPinnedScrollEdgeEffect = false

    public init(
        title: String,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        hidesNavigationBar: Bool = false,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent
    ) {
        self.title = title
        self.heroHeightPolicy = heroHeightPolicy
        self.hidesNavigationBar = hidesNavigationBar
        self.header = header
        self.bodyContent = bodyContent
    }

    public var body: some View {
        navigationBarConfigured {
            ScrollView {
                VStack(spacing: 0) {
                    DetailScrollPresentationHeader(
                        presentation: scrollPresentation,
                        header: header
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        bodyContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .trinketScreenBackground()
            .ignoresSafeArea(edges: .top)
            // Soft edge only once the inline title is pinned — keep hero art sharp at rest.
            .scrollEdgeEffectHidden(!showsPinnedScrollEdgeEffect, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: ScrollPresentation.self) { geometry in
                let topInset = geometry.contentInsets.top
                let headerBaseHeight = heroHeightPolicy.height(forWidth: geometry.containerSize.width)
                let threshold = headerBaseHeight - topInset - 44
                let offsetY = geometry.contentOffset.y + topInset
                return ScrollPresentation(
                    headerBaseHeight: headerBaseHeight,
                    heroOverscroll: HeroHeaderLayout.overscroll(
                        contentOffsetY: geometry.contentOffset.y,
                        topInset: topInset
                    ),
                    titleOpacity: min(max((offsetY - threshold) / 32, 0), 1)
                )
            } action: { _, newPresentation in
                // Scroll geometry fires every frame; skip redundant observer publications.
                guard scrollPresentation.value != newPresentation else { return }
                scrollPresentation.value = newPresentation

                let isPinned = newPresentation.titleOpacity >= 0.5
                if showsPinnedScrollEdgeEffect != isPinned {
                    showsPinnedScrollEdgeEffect = isPinned
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
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        DetailScrollNavigationTitle(
                            title: title,
                            presentation: scrollPresentation
                        )
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
    }
}

private struct ScrollPresentation: Equatable {
    static var initial: Self {
        Self(
            headerBaseHeight: HeroHeaderLayout.minimumHeaderHeight,
            heroOverscroll: 0,
            titleOpacity: 0
        )
    }

    var headerBaseHeight: CGFloat
    var heroOverscroll: CGFloat
    var titleOpacity: CGFloat
}

@MainActor
@Observable
private final class DetailScrollPresentationModel {
    var value = ScrollPresentation.initial
}

private struct DetailScrollPresentationHeader<Header: View>: View {
    let presentation: DetailScrollPresentationModel
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header

    var body: some View {
        header(presentation.value.headerBaseHeight, presentation.value.heroOverscroll)
    }
}

private struct DetailScrollNavigationTitle: View {
    let title: String
    let presentation: DetailScrollPresentationModel

    var body: some View {
        Text(title)
            .trinketTypography(.navigation)
            .opacity(presentation.value.titleOpacity)
    }
}

/// Shared section chrome for hero-detail body content.
public struct DetailSection<Content: View>: View {
    let title: String
    var sectionID: String?
    @ViewBuilder let content: () -> Content

    public init(
        _ title: String,
        sectionID: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.sectionID = sectionID
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(title)
                .trinketTypography(.rowTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.contentTopPadding)
                .accessibilityIdentifier(sectionID ?? title)

            content()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }
}
