import Foundation

@MainActor
protocol AuthRepository {
    func signInPlaceholder() async throws -> User
}

@MainActor
protocol BooksRepository {
    func searchBooks(query: String) async throws -> [Book]
    func fetchBook(id: String) async throws -> Book
    func fetchBookByISBN(_ isbn: String) async throws -> Book
}

@MainActor
protocol LibraryRepository {
    func fetchLibrary(shelf: Shelf?) async throws -> [LibraryItem]
    func upsertLibraryItem(bookID: String, shelf: Shelf, owned: Bool) async throws
    func updateProgress(bookID: String, progress: ReadingProgress) async throws
    func removeLibraryItem(bookID: String) async throws
}

@MainActor
protocol RecommendationsRepository {
    func fetchRecommendations() async throws -> [RecommendationItem]
}

@MainActor
protocol ProfileRepository {
    func fetchPreferences() async throws -> UserPreferenceProfile
    func updatePreferences(_ profile: UserPreferenceProfile) async throws
}

@MainActor
protocol GoalsRepository {
    func fetchCurrentGoal() async throws -> ReadingGoal
}
