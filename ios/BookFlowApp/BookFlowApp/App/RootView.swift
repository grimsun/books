import SwiftUI

struct RootView: View {
    @State private var environment = AppEnvironment.liveBooks()

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
