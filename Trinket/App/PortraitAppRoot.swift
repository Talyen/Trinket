import SwiftUI
import UIKit

struct PortraitAppRoot<Content: View>: UIViewControllerRepresentable {
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context: Context) -> PortraitHostingController<PortraitHostedContent<Content>> {
        PortraitHostingController(rootView: hostedContent(in: context))
    }

    func updateUIViewController(_ controller: PortraitHostingController<PortraitHostedContent<Content>>, context: Context) {
        controller.rootView = hostedContent(in: context)
    }

    private func hostedContent(in context: Context) -> PortraitHostedContent<Content> {
        PortraitHostedContent(content: content(), environment: context.environment)
    }
}

struct PortraitHostedContent<Content: View>: View {
    let content: Content
    let environment: EnvironmentValues

    var body: some View {
        // Keep hosting's accessibility environment intact while forwarding scene inputs.
        content
            .environment(\.scenePhase, environment.scenePhase)
            .environment(\.displayScale, environment.displayScale)
            .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
            .environment(\.layoutDirection, environment.layoutDirection)
    }
}

final class PortraitHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override var prefersInterfaceOrientationLocked: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfPrefersInterfaceOrientationLocked()
        view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
}
