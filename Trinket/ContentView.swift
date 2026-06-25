import SwiftUI

struct ContentView: View {
    @State private var game = TapTargetGame()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [.mint.opacity(0.25), .blue.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    header

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.8), lineWidth: 1)
                            )

                        Button {
                            game.hitTarget(in: playfieldSize(for: proxy.size))
                        } label: {
                            Text("+1")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 72)
                                .background(Circle().fill(.blue))
                                .shadow(radius: 8, y: 4)
                        }
                        .position(game.targetPosition)
                        .accessibilityLabel("Target")
                    }
                    .frame(height: playfieldSize(for: proxy.size).height)
                    .padding(.horizontal)

                    Button("Reset") {
                        game.reset(in: playfieldSize(for: proxy.size))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.vertical, 28)
            }
            .onAppear {
                game.reset(in: playfieldSize(for: proxy.size))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Trinket")
                .font(.largeTitle.bold())

            Text("Tap the target. Make the number go up.")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Score: \(game.score)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: game.score)
        }
    }

    private func playfieldSize(for screenSize: CGSize) -> CGSize {
        CGSize(width: max(280, screenSize.width - 32), height: max(320, screenSize.height * 0.52))
    }
}

#Preview {
    ContentView()
}
