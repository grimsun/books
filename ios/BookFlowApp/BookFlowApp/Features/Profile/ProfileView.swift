import SwiftUI

struct ProfileView: View {
    let environment: AppEnvironment

    @State private var goal: ReadingGoal?
    @State private var profile = UserPreferenceProfile.empty

    var body: some View {
        List {
            Section("Account") {
                Text(environment.session.currentUser?.displayName ?? "Mock Reader")
            }

            Section("Goal") {
                if let goal {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(goal.booksCompleted) of \(goal.booksTarget) books")
                            .font(.headline)
                        ProgressView(value: Double(goal.booksCompleted), total: Double(goal.booksTarget))
                    }
                }
            }

            Section("Preferences") {
                preferenceLine(title: "Favorite genres", value: profile.favoriteGenres.map(\.name).joined(separator: ", "))
                preferenceLine(title: "Favorite authors", value: profile.favoriteAuthors.map(\.name).joined(separator: ", "))
                preferenceLine(title: "Reading pace", value: profile.readingPace.title)
            }
        }
        .navigationTitle("Profile")
        .task {
            if goal == nil {
                goal = try? await environment.goalsRepository.fetchCurrentGoal()
                profile = (try? await environment.profileRepository.fetchPreferences()) ?? .empty
            }
        }
    }

    private func preferenceLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not set" : value)
        }
    }
}
