import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab

    init() {
        _selectedTab = State(initialValue: AppTab.launchDefault)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PlayView()
            }
            .tabItem {
                Label("Play", systemImage: "play.fill")
            }
            .tag(AppTab.play)

            NavigationStack {
                CardCollectionView(
                    title: "Heroes",
                    subtitle: "Build a party for the idle battle loop.",
                    iconName: "shield.lefthalf.filled",
                    cardTitles: ["Paladin", "Rogue", "Mage"]
                )
            }
            .tabItem {
                Label("Heroes", systemImage: "person.3.fill")
            }
            .tag(AppTab.heroes)

            NavigationStack {
                CardCollectionView(
                    title: "Pets",
                    subtitle: "Companions will bring abilities, stats, and charm.",
                    iconName: "pawprint.fill",
                    cardTitles: ["Wolf", "Hawk", "Drake"]
                )
            }
            .tabItem {
                Label("Pets", systemImage: "pawprint.fill")
            }
            .tag(AppTab.pets)

            NavigationStack {
                PlaceholderTabView(
                    title: "Homestead",
                    subtitle: "A future base for crafting, upgrades, and long-term progression.",
                    iconName: "house.fill"
                )
            }
            .tabItem {
                Label("Homestead", systemImage: "house.fill")
            }
            .tag(AppTab.homestead)

            NavigationStack {
                PlaceholderTabView(
                    title: "Options",
                    subtitle: "Settings, account, accessibility, audio, and credits will live here.",
                    iconName: "gearshape.fill"
                )
            }
            .tabItem {
                Label("Options", systemImage: "gearshape.fill")
            }
            .tag(AppTab.options)
        }
    }
}

private enum AppTab: String {
    case play
    case heroes
    case pets
    case homestead
    case options

    static var launchDefault: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-selectedTab"),
            arguments.indices.contains(flagIndex + 1),
            let tab = AppTab(rawValue: arguments[flagIndex + 1].lowercased())
        else {
            return .play
        }

        return tab
    }
}

private struct PlayView: View {
    var body: some View {
        PlaceholderTabView(
            title: "Play",
            subtitle: "Idle battles, encounter progress, and rewards will anchor the core loop here.",
            iconName: "gamecontroller.fill"
        )
    }
}

private struct CardCollectionView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let cardTitles: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: title, subtitle: subtitle, iconName: iconName)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(cardTitles, id: \.self) { cardTitle in
                        PlaceholderCard(title: cardTitle)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScreenHeader(title: title, subtitle: subtitle, iconName: iconName)
                .padding(32)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlaceholderCard: View {
    let title: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.regularMaterial)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("Card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) card")
    }
}

#Preview {
    ContentView()
}
