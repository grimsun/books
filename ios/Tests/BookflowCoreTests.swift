import Foundation
import Testing
@testable import BookflowCore

@Suite(.serialized)
@MainActor
struct BookflowCoreTests {
    @Test func savesLiveBooksAndProgressAcrossRepositoryInstances() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("library.json")
        let books = TestBooksRepository()
        let library = LocalLibraryRepository(booksRepository: books, storageURL: file)
        try await library.upsertLibraryItem(bookID: books.book.id, shelf: .reading, owned: true)
        try await library.updateProgress(bookID: books.book.id, progress: ReadingProgress(progressUnit: .page, progressValue: 42))
        try await library.upsertLibraryItem(bookID: books.book.id, shelf: .paused, owned: true)

        let restored = LocalLibraryRepository(booksRepository: books, storageURL: file)
        let saved = try #require(try await restored.fetchLibrary(shelf: .paused).first)
        #expect(saved.book == books.book)
        #expect(saved.progress?.progressValue == 42)
        #expect(saved.owned)
        #expect(try await restored.fetchLibrary(shelf: .reading).isEmpty)
        try await restored.removeLibraryItem(bookID: books.book.id)
        let empty = LocalLibraryRepository(booksRepository: books, storageURL: file, seedItems: MockSeedData.libraryItems)
        #expect(try await empty.fetchLibrary(shelf: nil).isEmpty)
    }

    @Test func rejectsInvalidProgressAndUnsavedBooks() async throws {
        let books = TestBooksRepository()
        let library = LocalLibraryRepository(booksRepository: books)
        await #expect(throws: LibraryError.self) {
            try await library.updateProgress(bookID: books.book.id, progress: ReadingProgress(progressUnit: .page, progressValue: 2))
        }
        try await library.upsertLibraryItem(bookID: books.book.id, shelf: .reading, owned: false)
        for progress in [ReadingProgress(progressUnit: .page, progressValue: -1),
                         ReadingProgress(progressUnit: .page, progressValue: 301),
                         ReadingProgress(progressUnit: .percent, progressValue: 101)] {
            await #expect(throws: LibraryError.self) {
                try await library.updateProgress(bookID: books.book.id, progress: progress)
            }
        }
        #expect(try await library.fetchLibrary(shelf: nil).first?.progress == nil)
    }

    @Test func corruptLibraryIsPreservedAndCannotBeOverwritten() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let original = Data("invalid library data".utf8)
        try original.write(to: file)
        let books = TestBooksRepository()
        let library = LocalLibraryRepository(booksRepository: books, storageURL: file, seedItems: MockSeedData.libraryItems)
        await #expect(throws: DecodingError.self) { _ = try await library.fetchLibrary(shelf: nil) }
        await #expect(throws: DecodingError.self) {
            try await library.upsertLibraryItem(bookID: books.book.id, shelf: .reading, owned: false)
        }
        #expect(try Data(contentsOf: file) == original)
    }

    @Test func progressUsesActualTotalAndUnits() {
        #expect(ReadingProgress(progressUnit: .page, progressValue: 150).fraction(pageCount: 300) == 0.5)
        #expect(ReadingProgress(progressUnit: .page, progressValue: 0).fraction(pageCount: 300) == 0)
        #expect(ReadingProgress(progressUnit: .page, progressValue: 100).fraction(pageCount: nil) == nil)
        #expect(ReadingProgress(progressUnit: .percent, progressValue: 75).fraction(pageCount: 300) == 0.75)
    }

    @Test func sessionSettingsAndReadingDatesPersistAndUseActualWeek() throws {
        let defaults = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let store = SessionStore(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
        let days = store.readingDays(now: saturday, calendar: calendar)
        #expect(days.count == 7)
        #expect(days[5].isToday)
        #expect(days.filter(\.isCompleted).isEmpty)
        store.toggleReading(on: days[0].date, now: saturday, calendar: calendar)
        store.toggleReading(on: days[6].date, now: saturday, calendar: calendar)
        store.currentUser = MockSeedData.defaultUser
        store.hasCompletedOnboarding = true
        store.showWeeklyRhythm = false
        let restored = SessionStore(defaults: defaults)
        #expect(restored.hasCompletedOnboarding)
        #expect(restored.currentUser == MockSeedData.defaultUser)
        #expect(!restored.showWeeklyRhythm)
        #expect(restored.readingDays(now: saturday, calendar: calendar).filter(\.isCompleted).count == 1)
        restored.toggleReading(on: days[0].date, now: saturday, calendar: calendar)
        #expect(restored.readingDays(now: saturday, calendar: calendar).filter(\.isCompleted).isEmpty)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: saturday)!
        #expect(restored.readingDays(now: nextWeek, calendar: calendar).filter(\.isCompleted).isEmpty)
    }

    @Test func preferencesPersist() async throws {
        let defaults = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        try await LocalProfileRepository(defaults: defaults).updatePreferences(MockSeedData.defaultPreferences)
        #expect(try await LocalProfileRepository(defaults: defaults).fetchPreferences() == MockSeedData.defaultPreferences)
    }

    @Test func newerSearchWinsWhenOlderRequestFinishesLast() async throws {
        let repository = TestBooksRepository()
        let model = BookSearchModel()
        let old = Task { await model.search(query: "old", using: repository, debounce: .zero) }
        try await Task.sleep(for: .milliseconds(10))
        await model.search(query: "new", using: repository, debounce: .zero)
        await old.value
        #expect(model.results.first?.title == "new")
        #expect(!model.isLoading)
    }

    @Test func cancelledSearchDoesNotShowAnErrorOrReplaceResults() async throws {
        let model = BookSearchModel()
        let task = Task { await model.search(query: "old", using: TestBooksRepository(), debounce: .seconds(1)) }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(model.results.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test func searchErrorsAreVisible() async {
        let repository = TestBooksRepository()
        repository.shouldFail = true
        let model = BookSearchModel()
        await model.search(query: "test", using: repository, debounce: .zero)
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)
    }

    @Test func openLibraryEncodesQueriesAndKeepsMetadataInDetails() async throws {
        let repository = makeOpenLibrary { request in
            if request.url!.path == "/search.json" {
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                #expect(query.first(where: { $0.name == "q" })?.value == "War & Peace #1")
                #expect(query.first(where: { $0.name == "fields" })!.value!.contains("author_key"))
                return (200, Self.searchJSON)
            }
            return (200, #"{"title":"Example","description":{"type":"/type/text","value":"About this book"},"covers":[-1]}"#)
        }
        let result = try #require(try await repository.searchBooks(query: "War & Peace #1").first)
        #expect(result.id == "/works/OL123W")
        #expect(result.authors.first?.id == "/authors/OL1A")
        #expect(result.pageCount == 300)
        let detail = try await repository.fetchBook(id: result.id)
        #expect(detail.authors == result.authors)
        #expect(detail.coverURL == result.coverURL)
        #expect(detail.isbn13 == result.isbn13)
        #expect(detail.pageCount == 300)
        #expect(detail.description == "About this book")
    }

    @Test func missingAuthorDoesNotBreakBookDetails() async throws {
        let repository = makeOpenLibrary { request in
            if request.url!.path.hasPrefix("/authors/") { return (404, "{}") }
            return (200, #"{"title":"Still available","authors":[{"author":{"key":"/authors/OL1A"}}]}"#)
        }
        let book = try await repository.fetchBook(id: "OL123W")
        #expect(book.title == "Still available")
        #expect(book.authors.isEmpty)
    }

    @Test func openLibraryReturnsEmptyResultsAndPropagatesRateLimits() async throws {
        let empty = makeOpenLibrary { _ in (200, #"{"docs":[]}"#) }
        #expect(try await empty.searchBooks(query: "unknown").isEmpty)
        let limited = makeOpenLibrary { _ in (429, "{}") }
        await #expect(throws: OpenLibraryRepositoryError.self) {
            _ = try await limited.searchBooks(query: "test")
        }
    }

    @Test func isbnLookupNormalizesHyphens() async throws {
        let repository = makeOpenLibrary { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(query.first(where: { $0.name == "q" })?.value == "isbn:9781234567890")
            return (200, Self.searchJSON)
        }
        #expect(try await repository.fetchBookByISBN("978-1-234567-89-0").id == "/works/OL123W")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BOOKFLOW_LIVE_TESTS"] == "1"))
    func liveOpenLibrarySearchDetailAndLibrarySave() async throws {
        let books = OpenLibraryBooksRepository()
        let result = try #require(try await books.searchBooks(query: "Dune Frank Herbert").first)
        let detail = try await books.fetchBook(id: result.id)
        #expect(!detail.title.isEmpty)
        #expect(!detail.authors.isEmpty)
        let library = LocalLibraryRepository(booksRepository: books)
        try await library.upsertLibraryItem(bookID: detail.id, shelf: .wantToRead, owned: false)
        #expect(try await library.fetchLibrary(shelf: .wantToRead).first?.book.id == detail.id)
    }

    private let defaultsSuite = "BookflowTests.\(UUID().uuidString)"

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: defaultsSuite))
    }

    private static let searchJSON = #"{"docs":[{"key":"OL123W","title":"Example","author_name":["A Writer"],"author_key":["OL1A"],"cover_i":12,"isbn":["9781234567890"],"number_of_pages_median":300}]}"#

    private func makeOpenLibrary(handler: @escaping (URLRequest) -> (Int, String)) -> OpenLibraryBooksRepository {
        StubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return OpenLibraryBooksRepository(session: URLSession(configuration: config), requestInterval: 0)
    }
}

@MainActor
private final class TestBooksRepository: BooksRepository {
    var shouldFail = false
    let book = Book(id: "/works/OL123W", title: "Example", subtitle: nil, authors: [], genres: [], description: nil,
                    coverURL: nil, pageCount: 300, publicationYear: 2000, isbn10: nil, isbn13: nil)

    func searchBooks(query: String) async throws -> [Book] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        if query == "old" { try? await Task.sleep(for: .milliseconds(80)) }
        return [Book(id: query, title: query, subtitle: nil, authors: [], genres: [], description: nil,
                     coverURL: nil, pageCount: nil, publicationYear: nil, isbn10: nil, isbn13: nil)]
    }

    func fetchBook(id: String) async throws -> Book { book }
    func fetchBookByISBN(_ isbn: String) async throws -> Book { book }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        let (status, json) = handler(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
