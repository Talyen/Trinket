import Observation
import SwiftUI
import TrinketDesignSystem

public struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var hidesNavigationBar = false
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    @State private var scrollPresentation = ScrollPresentation.initial
    @State private var showsPinnedScrollEdgeEffect = false

    public init(
        title: String,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        hidesNavigationBar: Bool = false,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent,
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
                        header: header,
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        bodyContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .trinketScreenBackground()
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.always)
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
                        topInset: topInset,
                    ),
                    titleOpacity: min(max((offsetY - threshold) / 32, 0), 1),
                )
            } action: { _, newPresentation in
                guard scrollPresentation != newPresentation else { return }
                scrollPresentation = newPresentation

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
                            presentation: scrollPresentation,
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
            titleOpacity: 0,
        )
    }

    var headerBaseHeight: CGFloat
    var heroOverscroll: CGFloat
    var titleOpacity: CGFloat
}

private struct DetailScrollPresentationHeader<Header: View>: View {
    let presentation: ScrollPresentation
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header

    var body: some View {
        header(presentation.headerBaseHeight, presentation.heroOverscroll)
    }
}

private struct DetailScrollNavigationTitle: View {
    let title: String
    let presentation: ScrollPresentation

    var body: some View {
        Text(title)
            .trinketTypography(.navigation)
            .opacity(presentation.titleOpacity)
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

struct DetailPrimaryActionFooter: View {
    let title: String
    var accessibilityIdentifier: String?
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(accessibilityIdentifier: accessibilityIdentifier ?? title)
        .trinketCenteredPrimaryAction()
        .disabled(isDisabled)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        .trinketSheetChromeIgnoresDismissDrag()
    }
}
