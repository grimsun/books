import SwiftUI

struct RootView: View {
    @State private var environment = AppEnvironment.app()

    var body: some View {
        Group {
            if environment.session.hasCompletedOnboarding {
                MainTabView(environment: environment)
            } else {
                NavigationStack {
                    OnboardingView(environment: environment)
                }
            }
        }
        .preferredColorScheme(.light)
        .tint(Color(red: 0.22, green: 0.45, blue: 0.29))
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            CoverImagePipeline.shared.discardDecodedImages()
        }
        #if DEBUG
        .overlay(alignment: .bottomLeading) {
            if ProcessInfo.processInfo.environment["BOOKFLOW_UI_TESTING"] == "1" {
                Text("Network requests")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("ui-test-network-request-count")
                    .accessibilityValue(String(NetworkDiagnostics.shared.requestCount))
                    .allowsHitTesting(false)
            }
        }
        #endif
    }
}

private struct MainTabView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(environment: environment)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                SearchView(environment: environment)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                LibraryView(environment: environment)
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            NavigationStack {
                ProfileView(environment: environment)
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}
