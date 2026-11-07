import Foundation

enum LibraryError: LocalizedError {
    case bookNotSaved
    case invalidProgress

    var errorDescription: String? {
        switch self {
        case .bookNotSaved: return "Save this book to your library before updating progress."
        case .invalidProgress: return "Enter a valid progress value within the book's page count or 0–100 percent."
        }
    }
}

@MainActor
final class LocalLibraryRepository: LibraryRepository {
    private let booksRepository: any BooksRepository
    private let storageURL: URL?
    private let loadError: Error?
    private var items: [LibraryItem]

    init(booksRepository: any BooksRepository, storageURL: URL? = nil, seedItems: [LibraryItem] = []) {
        self.booksRepository = booksRepository
        self.storageURL = storageURL
        if let storageURL, FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                items = try JSONDecoder().decode([LibraryItem].self, from: Data(contentsOf: storageURL))
                loadError = nil
            } catch {
                items = []
                loadError = error
            }
        } else {
            items = seedItems
            loadError = nil
        }
    }

    func fetchLibrary(shelf: Shelf?) async throws -> [LibraryItem] {
        if let loadError { throw loadError }
        return items.filter { shelf == nil || $0.shelf == shelf }
    }

    func upsertLibraryItem(bookID: String, shelf: Shelf, owned: Bool) async throws {
        let book: Book
        if let existing = items.first(where: { $0.id == bookID }) {
            book = existing.book
        } else {
            book = try await booksRepository.fetchBook(id: bookID)
        }
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == bookID }) {
            updated[index].shelf = shelf
            updated[index].owned = owned
        } else {
            updated.insert(LibraryItem(book: book, shelf: shelf, owned: owned), at: 0)
        }
        try save(updated)
    }

    func updateProgress(bookID: String, progress: ReadingProgress) async throws {
        guard let index = items.firstIndex(where: { $0.id == bookID }) else {
            throw LibraryError.bookNotSaved
        }
        let maximum = progress.progressUnit == .percent ? 100 : items[index].book.pageCount
        guard progress.progressValue >= 0, maximum.map({ progress.progressValue <= $0 }) ?? true else {
            throw LibraryError.invalidProgress
        }
        var updated = items
        updated[index].progress = progress
        try save(updated)
    }

    func removeLibraryItem(bookID: String) async throws {
        try save(items.filter { $0.id != bookID })
    }

    private func save(_ updated: [LibraryItem]) throws {
        if let loadError { throw loadError }
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: storageURL, options: .atomic)
        }
        items = updated
    }
}
