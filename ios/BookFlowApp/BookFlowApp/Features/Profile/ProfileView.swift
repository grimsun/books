import SwiftUI

struct ProfileView: View {
    let environment: AppEnvironment

    @State private var goal: ReadingGoal?
    @State private var profile = UserPreferenceProfile.empty

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                goalCard
                preferencesCard
                settingsCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if goal == nil {
                goal = try? await environment.goalsRepository.fetchCurrentGoal()
                profile = (try? await environment.profileRepository.fetchPreferences()) ?? .empty
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            HStack(spacing: 14) {
                Circle()
                    .fill(Color(.systemGreen).opacity(0.18))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color(.systemGreen))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(environment.session.currentUser?.displayName ?? "Mock Reader")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Your reading home")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var goalCard: some View {
        profileCard(title: "Goal") {
            if let goal {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(goal.booksCompleted) of \(goal.booksTarget) books")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    ProgressView(value: Double(goal.booksCompleted), total: Double(goal.booksTarget))
                        .tint(Color(.systemGreen))
                }
            } else {
                Text("No goal set")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var preferencesCard: some View {
        profileCard(title: "Preferences") {
            VStack(alignment: .leading, spacing: 14) {
                preferenceLine(title: "Favorite genres", value: profile.favoriteGenres.map(\.name).joined(separator: ", "))
                preferenceLine(title: "Favorite authors", value: profile.favoriteAuthors.map(\.name).joined(separator: ", "))
                preferenceLine(title: "Reading pace", value: profile.readingPace.title)
            }
        }
    }

    private var settingsCard: some View {
        profileCard(title: "App") {
            NavigationLink {
                SettingsView(session: environment.session)
            } label: {
                HStack {
                    Text("Settings")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func profileCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func preferenceLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not set" : value)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct SettingsView: View {
    @Bindable var session: SessionStore

    var body: some View {
        List {
            Section("Home") {
                Toggle("Show weekly rhythm", isOn: $session.showWeeklyRhythm)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
