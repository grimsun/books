import Foundation

enum MockRepositoryError: Error {
    case bookNotFound
}

final class MockAuthRepository: AuthRepository {
    func signInPlaceholder() async throws -> User {
        MockSeedData.defaultUser
    }
}

final class MockBooksRepository: BooksRepository {
    private let books = MockSeedData.books

    func searchBooks(query: String) async throws -> [Book] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return books
        }

        let normalized = query.lowercased()
        return books.filter { book in
            book.title.lowercased().contains(normalized) ||
            book.authors.contains(where: { $0.name.lowercased().contains(normalized) }) ||
            book.genres.contains(where: { $0.name.lowercased().contains(normalized) })
        }
    }

    func fetchBook(id: String) async throws -> Book {
        guard let book = books.first(where: { $0.id == id }) else {
            throw MockRepositoryError.bookNotFound
        }
        return book
    }

    func fetchBookByISBN(_ isbn: String) async throws -> Book {
        guard let book = books.first(where: { $0.isbn10 == isbn || $0.isbn13 == isbn }) else {
            throw MockRepositoryError.bookNotFound
        }
        return book
    }
}

final class MockLibraryRepository: LibraryRepository {
    private var items = MockSeedData.libraryItems

    func fetchLibrary(shelf: Shelf?) async throws -> [LibraryItem] {
        guard let shelf else { return items }
        return items.filter { $0.shelf == shelf }
    }

    func upsertLibraryItem(bookID: String, shelf: Shelf, owned: Bool) async throws {
        guard let book = MockSeedData.books.first(where: { $0.id == bookID }) else {
            throw MockRepositoryError.bookNotFound
        }

        if let index = items.firstIndex(where: { $0.book.id == bookID }) {
            items[index].shelf = shelf
            items[index].owned = owned
        } else {
            items.insert(
                LibraryItem(book: book, shelf: shelf, owned: owned, personalRating: nil, privateNote: nil, progress: nil),
                at: 0
            )
        }
    }

    func updateProgress(bookID: String, progress: ReadingProgress) async throws {
        guard let index = items.firstIndex(where: { $0.book.id == bookID }) else {
            throw MockRepositoryError.bookNotFound
        }
        items[index].progress = progress
    }

    func removeLibraryItem(bookID: String) async throws {
        items.removeAll { $0.book.id == bookID }
    }
}

final class MockRecommendationsRepository: RecommendationsRepository {
    func fetchRecommendations() async throws -> [RecommendationItem] {
        MockSeedData.recommendations
    }
}

final class MockProfileRepository: ProfileRepository {
    private var profile = MockSeedData.defaultPreferences

    func fetchPreferences() async throws -> UserPreferenceProfile {
        profile
    }

    func updatePreferences(_ profile: UserPreferenceProfile) async throws {
        self.profile = profile
    }
}

final class MockGoalsRepository: GoalsRepository {
    func fetchCurrentGoal() async throws -> ReadingGoal {
        MockSeedData.currentGoal
    }
}
