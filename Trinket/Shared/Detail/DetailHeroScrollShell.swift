import SwiftUI
import TrinketDesignSystem

/// Shared scroll + toolbar chrome for full-bleed hero detail sheets (combatants, items).
struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let backgroundMode: BackgroundMode
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var showsDoneButton = false
    var hidesNavigationBar = false
    var onDone: (() -> Void)?
    @ViewBuilder let header: (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    @State private var headerBaseHeight: CGFloat = 300
    @State private var heroOverscroll: CGFloat = 0
    @State private var titleOpacity: CGFloat = 0

    init(
        title: String,
        backgroundMode: BackgroundMode = .standard,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        showsDoneButton: Bool = false,
        hidesNavigationBar: Bool = false,
        onDone: (() -> Void)? = nil,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat, _ overscroll: CGFloat) -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent
    ) {
        self.title = title
        self.backgroundMode = backgroundMode
        self.heroHeightPolicy = heroHeightPolicy
        self.showsDoneButton = showsDoneButton
        self.hidesNavigationBar = hidesNavigationBar
        self.onDone = onDone
        self.header = header
        self.bodyContent = bodyContent
    }

    var body: some View {
        navigationBarConfigured {
            ScrollView {
                VStack(spacing: 0) {
                    header(headerBaseHeight, heroOverscroll)

                    VStack(alignment: .leading, spacing: 0) {
                        bodyContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .trinketScreenBackground(backgroundMode)
                }
            }
            .ignoresSafeArea(edges: .top)
            // Hide the system scroll-edge blur so full-bleed hero art stays sharp under clear toolbar.
            .scrollEdgeEffectHidden(true, for: .top)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                let topInset = geometry.contentInsets.top
                return ScrollMetrics(
                    containerWidth: geometry.containerSize.width,
                    offsetY: geometry.contentOffset.y + topInset,
                    topInset: topInset,
                    overscroll: HeroHeaderLayout.overscroll(
                        contentOffsetY: geometry.contentOffset.y,
                        topInset: topInset
                    )
                )
            } action: { _, metrics in
                headerBaseHeight = heroHeightPolicy.height(forWidth: metrics.containerWidth)
                heroOverscroll = metrics.overscroll
                let threshold = headerBaseHeight - metrics.topInset - 44
                titleOpacity = min(max((metrics.offsetY - threshold) / 32, 0), 1)
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
                            .opacity(titleOpacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
    }

    private struct ScrollMetrics: Equatable {
        var containerWidth: CGFloat
        var offsetY: CGFloat
        var topInset: CGFloat
        var overscroll: CGFloat
    }
}

/// Shared section chrome for hero-detail body content.
struct DetailSection<Content: View>: View {
    let title: String
    var sectionID: String?
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        sectionID: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.sectionID = sectionID
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(title)
                .trinketTypography(.cardTitle)
                .foregroundStyle(.secondary)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.contentTopPadding)
                .accessibilityIdentifier(sectionID ?? title)

            content()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }
}
