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
    @State private var headerBaseHeight: CGFloat = HeroHeaderLayout.minimumHeaderHeight

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
                    header(headerBaseHeight)

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
            .onScrollGeometryChange(for: HeroHeaderScrollMetrics.self) { geometry in
                let topInset = geometry.contentInsets.top
                let baseHeight = heroHeightPolicy.height(forWidth: geometry.containerSize.width)
                let threshold = baseHeight - topInset - 44
                let offsetY = geometry.contentOffset.y + topInset
                let opacity = min(max((offsetY - threshold) / 32, 0), 1)
                return HeroHeaderScrollMetrics(baseHeight: baseHeight, titleOpacity: opacity)
            } action: { _, metrics in
                if headerBaseHeight != metrics.baseHeight {
                    headerBaseHeight = metrics.baseHeight
                }
                if titleOpacity != metrics.titleOpacity {
                    titleOpacity = metrics.titleOpacity
                }
                let isPinned = metrics.titleOpacity >= 0.5
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

private struct HeroHeaderScrollMetrics: Equatable {
    let baseHeight: CGFloat
    let titleOpacity: CGFloat
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
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text(title)
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
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .trinketSheetChromeIgnoresDismissDrag()
    }
}
