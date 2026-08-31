import Observation
import SwiftUI
import TrinketDesignSystem

public struct DetailHeroScrollShell<Header: View, BodyContent: View>: View {
    let title: String
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    var hidesNavigationBar = false
    @ViewBuilder let header: (_ baseHeight: CGFloat) -> Header
    @ViewBuilder let bodyContent: () -> BodyContent

    @State private var showsPinnedScrollEdgeEffect = false
    @State private var titleOpacity: CGFloat = 0

    public init(
        title: String,
        heroHeightPolicy: HeroHeaderLayout.HeightPolicy = .portrait,
        hidesNavigationBar: Bool = false,
        @ViewBuilder header: @escaping (_ baseHeight: CGFloat) -> Header,
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
                    DetailHeroHeaderContainer(
                        heroHeightPolicy: heroHeightPolicy,
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
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let topInset = geometry.contentInsets.top
                let headerBaseHeight = heroHeightPolicy.height(forWidth: geometry.containerSize.width)
                let threshold = headerBaseHeight - topInset - 44
                let offsetY = geometry.contentOffset.y + topInset
                return min(max((offsetY - threshold) / 32, 0), 1)
            } action: { _, newOpacity in
                if titleOpacity != newOpacity {
                    titleOpacity = newOpacity
                }
                let isPinned = newOpacity >= 0.5
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
                            opacity: titleOpacity,
                        )
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
    }
}

private struct DetailHeroHeaderContainer<Header: View>: View {
    let heroHeightPolicy: HeroHeaderLayout.HeightPolicy
    @ViewBuilder let header: (_ baseHeight: CGFloat) -> Header
    @State private var headerBaseHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight

    var body: some View {
        header(headerBaseHeight)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                heroHeightPolicy.height(forWidth: geometry.containerSize.width)
            } action: { _, newHeight in
                if headerBaseHeight != newHeight {
                    headerBaseHeight = newHeight
                }
            }
    }
}

private struct DetailScrollNavigationTitle: View {
    let title: String
    let opacity: CGFloat

    var body: some View {
        Text(title)
            .trinketTypography(.navigation)
            .opacity(opacity)
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
