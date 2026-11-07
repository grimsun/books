import Foundation

enum OpenLibraryRepositoryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "This book link is invalid."
        case .invalidResponse: return "Open Library returned an unexpected response. Please try again."
        case .notFound: return "This book could not be found."
        case .httpStatus(429): return "Open Library is busy. Please wait a moment and try again."
        case .httpStatus: return "Open Library is unavailable. Please try again later."
        }
    }
}

@MainActor
final class OpenLibraryBooksRepository: BooksRepository {
    private let session: URLSession?
    private let decodingWorker = OpenLibraryDecodingWorker()
    private let fallback = MockBooksRepository()
    private var cachedBooks: [String: Book] = [:]
    private var detailedBookIDs: Set<String> = []
    private var cachedSearches: [String: [Book]] = [:]
    private var nextRequestDate = Date.distantPast
    private let requestInterval: TimeInterval

    init(session: URLSession? = nil, requestInterval: TimeInterval = 1) {
        self.session = session
        self.requestInterval = requestInterval
    }

    func searchBooks(query: String) async throws -> [Book] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return try await fallback.searchBooks(query: query)
        }

        if let cached = cachedSearches[trimmedQuery] { return cached }
        let books = try await search(query: trimmedQuery, limit: 20)
        cachedSearches[trimmedQuery] = books
        return books
    }

    func fetchBook(id: String) async throws -> Book {
        guard let workID = Self.workID(id) else {
            return try await fallback.fetchBook(id: id)
        }
        if detailedBookIDs.contains(workID), let cached = cachedBooks[workID] { return cached }
        let cached = cachedBooks[workID]
        let work: OpenLibraryWorkResponse
        do {
            work = try await request(urlString: "https://openlibrary.org\(workID).json")
        } catch {
            try Task.checkCancellation()
            if let cached { return cached }
            throw error
        }
        var authors = cached?.authors ?? []
        if authors.isEmpty {
            authors = try await fetchAuthors(for: work.authors)
        }
        let genres = work.subjects.map { subjects in
            subjects.prefix(3).enumerated().map { index, name in
                Genre(id: "\(workID)-genre-\(index)", name: name)
            }
        } ?? cached?.genres ?? []
        let book = Book(
            id: workID,
            title: work.title,
            subtitle: work.subtitle,
            authors: authors,
            genres: genres,
            description: work.description?.textValue,
            coverURL: Self.coverURL(coverID: work.covers?.first(where: { $0 > 0 })) ?? cached?.coverURL,
            pageCount: cached?.pageCount,
            publicationYear: Self.extractYear(from: work.firstPublishDate) ?? cached?.publicationYear,
            isbn10: cached?.isbn10,
            isbn13: cached?.isbn13
        )
        cachedBooks[workID] = book
        detailedBookIDs.insert(workID)
        return book
    }

    func fetchBookByISBN(_ isbn: String) async throws -> Book {
        let normalizedISBN = isbn.filter { !$0.isWhitespace && $0 != "-" }.uppercased()
        guard !normalizedISBN.isEmpty else {
            throw OpenLibraryRepositoryError.notFound
        }

        guard let book = try await search(query: "isbn:\(normalizedISBN)", limit: 1).first else {
            throw OpenLibraryRepositoryError.notFound
        }
        return book
    }

    private func search(query: String, limit: Int) async throws -> [Book] {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "fields", value: "key,title,author_name,author_key,first_publish_year,cover_i,isbn,subject,number_of_pages_median")
        ]
        guard let url = components.url else { throw OpenLibraryRepositoryError.invalidURL }
        let response: OpenLibrarySearchResponse = try await request(urlString: url.absoluteString)
        var seen: Set<String> = []
        let books = response.docs.map(Self.mapSearchDoc).filter { seen.insert($0.id).inserted }
        for book in books where !detailedBookIDs.contains(book.id) { cachedBooks[book.id] = book }
        return books
    }

    private func fetchAuthors(for refs: [OpenLibraryAuthorReference]?) async throws -> [Author] {
        guard let refs, !refs.isEmpty else { return [] }
        var authors: [Author] = []
        for ref in refs.prefix(3) {
            do {
                let author: OpenLibraryAuthorResponse = try await request(urlString: "https://openlibrary.org\(ref.author.key).json")
                authors.append(Author(id: ref.author.key, name: author.name))
            } catch {
                try Task.checkCancellation()
                // Author enrichment should never prevent opening the book itself.
            }
        }
        return authors
    }

    private func request<T: Decodable & Sendable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw OpenLibraryRepositoryError.invalidURL
        }

        while nextRequestDate > Date() {
            try await Task.sleep(for: .seconds(max(0, nextRequestDate.timeIntervalSinceNow)))
        }
        try Task.checkCancellation()
        nextRequestDate = Date().addingTimeInterval(requestInterval)

        var request = URLRequest(url: url)
        request.setValue("Bookflow iOS Prototype", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        #if DEBUG
        NetworkDiagnostics.shared.recordRequest()
        #endif
        let (data, response) = try await decodingWorker.data(for: request, session: session)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenLibraryRepositoryError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw httpResponse.statusCode == 404 ? OpenLibraryRepositoryError.notFound : .httpStatus(httpResponse.statusCode)
        }

        let decoded = try await decodingWorker.decode(T.self, from: data)
        try Task.checkCancellation()
        return decoded
    }

    private static func mapSearchDoc(_ doc: OpenLibrarySearchDocument) -> Book {
        let genres = (doc.subject ?? []).prefix(3).enumerated().map { index, name in
            Genre(id: "\(doc.key)-genre-\(index)", name: name)
        }

        return Book(
            id: workID(doc.key) ?? doc.key,
            title: doc.title,
            subtitle: nil,
            authors: (doc.authorName ?? []).enumerated().map { index, name in
                let key = doc.authorKey?[safe: index]
                return Author(id: key.map { $0.hasPrefix("/") ? $0 : "/authors/\($0)" } ?? "\(doc.key)-author-\(index)", name: name)
            },
            genres: genres,
            description: nil,
            coverURL: coverURL(coverID: doc.coverID),
            pageCount: doc.pageCount.flatMap { $0 > 0 ? $0 : nil },
            publicationYear: doc.firstPublishYear,
            isbn10: doc.isbn?.first(where: { $0.count == 10 }),
            isbn13: doc.isbn?.first(where: { $0.count == 13 })
        )
    }

    private static func coverURL(coverID: Int?) -> URL? {
        guard let coverID, coverID > 0 else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg?default=false")
    }

    private static func workID(_ id: String) -> String? {
        let identifier = id.hasPrefix("/works/") ? String(id.dropFirst(7)) : id
        guard identifier.range(of: "^OL[0-9]+W$", options: .regularExpression) != nil else { return nil }
        return "/works/\(identifier)"
    }

    private static func extractYear(from firstPublishDate: String?) -> Int? {
        guard let firstPublishDate else { return nil }
        guard let range = firstPublishDate.range(of: "\\b[12][0-9]{3}\\b", options: .regularExpression) else { return nil }
        return Int(firstPublishDate[range])
    }
}

private actor OpenLibraryDecodingWorker {
    func data(for request: URLRequest, session: URLSession?) async throws -> (Data, URLResponse) {
        try await (session ?? .shared).data(for: request)
    }

    func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) throws -> T {
        try Task.checkCancellation()
        return try JSONDecoder().decode(type, from: data)
    }
}

nonisolated private struct OpenLibrarySearchResponse: Decodable, Sendable {
    let docs: [OpenLibrarySearchDocument]
}

nonisolated private struct OpenLibrarySearchDocument: Decodable, Sendable {
    let key: String
    let title: String
    let authorName: [String]?
    let authorKey: [String]?
    let firstPublishYear: Int?
    let coverID: Int?
    let isbn: [String]?
    let subject: [String]?
    let pageCount: Int?

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case authorKey = "author_key"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case isbn
        case subject
        case pageCount = "number_of_pages_median"
    }
}

nonisolated private struct OpenLibraryWorkResponse: Decodable, Sendable {
    let title: String
    let subtitle: String?
    let description: OpenLibraryDescription?
    let covers: [Int]?
    let subjects: [String]?
    let firstPublishDate: String?
    let authors: [OpenLibraryAuthorReference]?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case description
        case covers
        case subjects
        case authors
        case firstPublishDate = "first_publish_date"
    }
}

nonisolated private struct OpenLibraryDescription: Decodable, Sendable {
    let value: String?

    var textValue: String? { value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let objectValue = try? container.decode([String: String].self) {
            value = objectValue["value"]
        } else {
            value = nil
        }
    }
}

nonisolated private struct OpenLibraryAuthorReference: Decodable, Sendable {
    let author: OpenLibraryKeyReference
}

nonisolated private struct OpenLibraryKeyReference: Decodable, Sendable {
    let key: String
}

nonisolated private struct OpenLibraryAuthorResponse: Decodable, Sendable {
    let name: String
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
