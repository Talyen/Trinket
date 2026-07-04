import SwiftUI


struct BattleOutcomeShell<Content: View>: View {
    let symbolName: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String
    @ViewBuilder let content: () -> Content
    let primaryButtonTitle: String
    let primaryButtonAccessibilityIdentifier: String
    let primaryButtonTint: Color?
    let onPrimaryAction: () -> Void

    @State private var symbolAnimationCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: symbolName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .accessibilityHidden(true)
                    .symbolEffect(.bounce, value: symbolAnimationCount)
                    .onAppear {
                        symbolAnimationCount += 1
                    }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier(titleAccessibilityIdentifier)

                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                content()

                Button(action: onPrimaryAction) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                // UIStyleCheck: allow - battle outcomes use the native prominent primary action.
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(primaryButtonTint)
                .accessibilityIdentifier(primaryButtonAccessibilityIdentifier)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BattleOutcomeInfoSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .trinketCardSurface()
    }
}

struct BattleOutcomeRewardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityIdentifier(title)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .trinketCardSurface()
    }
}

struct BattleOutcomeRewardRow: View {
    let symbolName: String
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
        }
    }
}
