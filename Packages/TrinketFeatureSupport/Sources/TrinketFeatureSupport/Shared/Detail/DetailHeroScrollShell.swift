import SwiftUI
import TrinketDesignSystem

/// Shared scroll + toolbar chrome for full-bleed hero detail sheets (combatants, items).
public struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var showsDoneButton = false
    var hidesNavigationBar = false
    var onDone: (() -> Void)?
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    @State private var presentation = ScrollPresentation.initial

    public init(
        title: String,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        showsDoneButton: Bool = false,
        hidesNavigationBar: Bool = false,
        onDone: (() -> Void)? = nil,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent
    ) {
        self.title = title
        self.heroHeightPolicy = heroHeightPolicy
        self.showsDoneButton = showsDoneButton
        self.hidesNavigationBar = hidesNavigationBar
        self.onDone = onDone
        self.header = header
        self.bodyContent = bodyContent
    }

    public var body: some View {
        navigationBarConfigured {
            ScrollView {
                VStack(spacing: 0) {
                    header(presentation.headerBaseHeight, presentation.heroOverscroll)

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
                // Scroll geometry fires every frame; skip no-op writes so hero
                // chrome does not invalidate when values are unchanged.
                guard presentation != newPresentation else { return }
                presentation = newPresentation
            }
        }
    }

    /// Matches the inline title fade so edge blur arrives with pinned chrome, not over hero art.
    private var showsPinnedScrollEdgeEffect: Bool {
        presentation.titleOpacity >= 0.5
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
                    if showsDoneButton {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                onDone?()
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .trinketTypography(.navigation)
                            .opacity(presentation.titleOpacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
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
