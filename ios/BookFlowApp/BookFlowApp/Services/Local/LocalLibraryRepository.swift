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
    private let storage: LibraryStorageWorker

    init(booksRepository: any BooksRepository, storageURL: URL? = nil, seedItems: [LibraryItem] = []) {
        self.booksRepository = booksRepository
        storage = LibraryStorageWorker(storageURL: storageURL, seedItems: seedItems)
    }

    func fetchLibrary(shelf: Shelf?) async throws -> [LibraryItem] {
        try await storage.fetch(shelf: shelf)
    }

    func upsertLibraryItem(bookID: String, shelf: Shelf, owned: Bool) async throws {
        // Resolve remotely outside the storage actor, then merge with its latest state.
        let book: Book
        if let saved = try await storage.book(id: bookID) {
            book = saved
        } else {
            book = try await booksRepository.fetchBook(id: bookID)
        }
        try await storage.upsert(book: book, shelf: shelf, owned: owned)
    }

    func updateProgress(bookID: String, progress: ReadingProgress) async throws {
        try await storage.updateProgress(bookID: bookID, progress: progress)
    }

    func removeLibraryItem(bookID: String) async throws {
        try await storage.remove(bookID: bookID)
    }
}

// No suspensions inside a transaction: concurrent callers cannot overwrite a newer save.
private actor LibraryStorageWorker {
    private let storageURL: URL?
    private var loaded: Result<[LibraryItem], Error>?
    private var seedItems: [LibraryItem]

    init(storageURL: URL?, seedItems: [LibraryItem]) {
        self.storageURL = storageURL
        self.seedItems = seedItems
    }

    private func load() throws -> [LibraryItem] {
        if let loaded { return try loaded.get() }
        let result = Result {
            if let storageURL, FileManager.default.fileExists(atPath: storageURL.path) {
                return try JSONDecoder().decode([LibraryItem].self, from: Data(contentsOf: storageURL))
            }
            return seedItems
        }
        loaded = result
        seedItems = []
        return try result.get()
    }

    func fetch(shelf: Shelf?) throws -> [LibraryItem] {
        let items = try load()
        guard let shelf else { return items }
        return items.filter { $0.shelf == shelf }
    }

    func book(id: String) throws -> Book? {
        try load().first(where: { $0.book.id == id })?.book
    }

    func upsert(book: Book, shelf: Shelf, owned: Bool) throws {
        var updated = try load()
        if let index = updated.firstIndex(where: { $0.book.id == book.id }) {
            updated[index].shelf = shelf
            updated[index].owned = owned
        } else {
            updated.insert(LibraryItem(book: book, shelf: shelf, owned: owned), at: 0)
        }
        try save(updated)
    }

    func updateProgress(bookID: String, progress: ReadingProgress) throws {
        var updated = try load()
        guard let index = updated.firstIndex(where: { $0.book.id == bookID }) else {
            throw LibraryError.bookNotSaved
        }
        let maximum = progress.progressUnit == .percent ? 100 : updated[index].book.pageCount
        guard progress.progressValue >= 0, maximum.map({ progress.progressValue <= $0 }) ?? true else {
            throw LibraryError.invalidProgress
        }
        updated[index].progress = progress
        try save(updated)
    }

    func remove(bookID: String) throws {
        try save(load().filter { $0.book.id != bookID })
    }

    private func save(_ updated: [LibraryItem]) throws {
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: storageURL, options: .atomic)
        }
        loaded = .success(updated)
    }
}
