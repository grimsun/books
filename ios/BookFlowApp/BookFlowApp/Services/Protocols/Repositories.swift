import Foundation

protocol AuthRepository {
    func signInPlaceholder() async throws -> User
}

protocol BooksRepository {
    func searchBooks(query: String) async throws -> [Book]
    func fetchBook(id: String) async throws -> Book
    func fetchBookByISBN(_ isbn: String) async throws -> Book
}

protocol LibraryRepository {
    func fetchLibrary(shelf: Shelf?) async throws -> [LibraryItem]
    func upsertLibraryItem(bookID: String, shelf: Shelf, owned: Bool) async throws
    func updateProgress(bookID: String, progress: ReadingProgress) async throws
    func removeLibraryItem(bookID: String) async throws
}

protocol RecommendationsRepository {
    func fetchRecommendations() async throws -> [RecommendationItem]
}

protocol ProfileRepository {
    func fetchPreferences() async throws -> UserPreferenceProfile
    func updatePreferences(_ profile: UserPreferenceProfile) async throws
}

protocol GoalsRepository {
    func fetchCurrentGoal() async throws -> ReadingGoal
}
