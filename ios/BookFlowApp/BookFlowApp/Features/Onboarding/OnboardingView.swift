import SwiftUI

struct OnboardingView: View {
    let environment: AppEnvironment

    @State private var selectedGenres = Set<Genre>()
    @State private var selectedAuthors = Set<Author>()
    @State private var readingPace: ReadingPace = .moderate
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    private let availableGenres = [MockSeedData.fantasy, MockSeedData.literary, MockSeedData.sciFi, MockSeedData.classics]
    private let availableAuthors = [MockSeedData.leGuin, MockSeedData.butler, MockSeedData.murakami, MockSeedData.martel]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Bookflow")
                    .font(.largeTitle.bold())

                Text("Track what you read and get recommendations that feel tailored, not generic.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                sectionTitle("Favorite genres")
                FlowLayout(items: availableGenres, selection: $selectedGenres)

                sectionTitle("Favorite authors")
                FlowLayout(items: availableAuthors, selection: $selectedAuthors)

                sectionTitle("Reading pace")
                Picker("Reading pace", selection: $readingPace) {
                    ForEach(ReadingPace.allCases) { pace in
                        Text(pace.title).tag(pace)
                    }
                }
                .pickerStyle(.segmented)

                Button(isSigningIn ? "Signing In..." : "Continue") {
                    Task { await continueFlow() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSigningIn)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
    }

    @MainActor
    private func continueFlow() async {
        isSigningIn = true
        defer { isSigningIn = false }

        errorMessage = nil
        do {
            let user = try await environment.authRepository.signInPlaceholder()
            let profile = UserPreferenceProfile(
                favoriteGenres: availableGenres.filter { selectedGenres.contains($0) },
                favoriteAuthors: availableAuthors.filter { selectedAuthors.contains($0) },
                dislikedGenres: [],
                readingPace: readingPace
            )
            try await environment.profileRepository.updatePreferences(profile)
            environment.session.currentUser = user
            environment.session.hasCompletedOnboarding = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private protocol FlowSelectable: Identifiable, Hashable {
    var name: String { get }
}

extension Genre: FlowSelectable {}
extension Author: FlowSelectable {}

private struct FlowLayout<Item: FlowSelectable>: View {
    let items: [Item]
    @Binding var selection: Set<Item>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                Button(item.name) {
                    if selection.contains(item) {
                        selection.remove(item)
                    } else {
                        selection.insert(item)
                    }
                }
                .buttonStyle(.bordered)
                .tint(selection.contains(item) ? .accentColor : .secondary)
            }
        }
    }
}
