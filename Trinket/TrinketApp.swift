import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct TrinketApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-disableAnimations") {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            #endif
        }
        
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureGlobalAppearance() {
        #if canImport(UIKit)
        // Configure Global Tab Bar Appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        #endif
    }
}
