import Foundation
import Observation

@Observable
@MainActor
final class HomeFeedStore {
    // The current discovery feed is curated sample data and can render immediately.
    var recommendations = MockSeedData.recommendations
    var currentlyReading = MockSeedData.libraryItems.filter { $0.shelf == .reading }
    var selectedMoodID = MockSeedData.moodShelves.first?.id ?? ""
    var selectedReadingBookID: String?
    private var loadedRevision: Int?

    func refresh(environment: AppEnvironment) async {
        let revision = environment.libraryRevision
        guard loadedRevision != revision else { return }
        do {
            let books = try await environment.libraryRepository.fetchLibrary(shelf: .reading)
            try Task.checkCancellation()
            if currentlyReading != books { currentlyReading = books }
            loadedRevision = revision
        } catch {
            // Keep the existing feed stable; Library presents storage errors and retry.
        }
    }
}
