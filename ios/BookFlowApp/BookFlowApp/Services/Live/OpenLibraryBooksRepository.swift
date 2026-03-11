import Foundation

enum OpenLibraryRepositoryError: Error {
    case invalidURL
    case invalidResponse
    case notFound
}

final class OpenLibraryBooksRepository: BooksRepository {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let fallback = MockBooksRepository()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchBooks(query: String) async throws -> [Book] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return try await fallback.searchBooks(query: query)
        }

        let encoded = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery
        let urlString = "https://openlibrary.org/search.json?q=\(encoded)&limit=20&fields=key,title,author_name,first_publish_year,cover_i,isbn,subject"
        let response: OpenLibrarySearchResponse = try await request(urlString: urlString)
        let books = response.docs.map(Self.mapSearchDoc)
        return books.isEmpty ? try await fallback.searchBooks(query: query) : books
    }

    func fetchBook(id: String) async throws -> Book {
        guard id.hasPrefix("/") else {
            return try await fallback.fetchBook(id: id)
        }

        let work: OpenLibraryWorkResponse = try await request(urlString: "https://openlibrary.org\(id).json")
        let authors = try await fetchAuthors(for: work.authors)

        return Book(
            id: id,
            title: work.title,
            subtitle: work.subtitle,
            authors: authors,
            genres: (work.subjects ?? []).prefix(3).enumerated().map { index, name in
                Genre(id: "\(id)-genre-\(index)", name: name)
            },
            description: work.description?.textValue,
            coverURL: Self.coverURL(coverID: work.covers?.first),
            pageCount: nil,
            publicationYear: Self.extractYear(from: work.firstPublishDate),
            isbn10: nil,
            isbn13: nil
        )
    }

    func fetchBookByISBN(_ isbn: String) async throws -> Book {
        let normalizedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedISBN.isEmpty else {
            throw OpenLibraryRepositoryError.notFound
        }

        let encoded = "isbn:\(normalizedISBN)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedISBN
        let urlString = "https://openlibrary.org/search.json?q=\(encoded)&limit=1&fields=key,title,author_name,first_publish_year,cover_i,isbn,subject"
        let response: OpenLibrarySearchResponse = try await request(urlString: urlString)

        guard let first = response.docs.first else {
            return try await fallback.fetchBookByISBN(isbn)
        }

        return Self.mapSearchDoc(first)
    }

    private func fetchAuthors(for refs: [OpenLibraryAuthorReference]?) async throws -> [Author] {
        guard let refs, !refs.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: Author?.self) { group in
            for ref in refs.prefix(3) {
                group.addTask {
                    guard let key = ref.author.key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                        return nil
                    }
                    let author: OpenLibraryAuthorResponse = try await self.request(urlString: "https://openlibrary.org\(key).json")
                    return Author(id: ref.author.key, name: author.name)
                }
            }

            var authors: [Author] = []
            for try await author in group {
                if let author {
                    authors.append(author)
                }
            }
            return authors
        }
    }

    private func request<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw OpenLibraryRepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bookflow iOS Prototype", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw OpenLibraryRepositoryError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
    }

    private static func mapSearchDoc(_ doc: OpenLibrarySearchDocument) -> Book {
        let genres = (doc.subject ?? []).prefix(3).enumerated().map { index, name in
            Genre(id: "\(doc.key)-genre-\(index)", name: name)
        }

        return Book(
            id: doc.key,
            title: doc.title,
            subtitle: nil,
            authors: (doc.authorName ?? []).enumerated().map { index, name in
                Author(id: doc.authorKey?[safe: index] ?? "\(doc.key)-author-\(index)", name: name)
            },
            genres: genres,
            description: nil,
            coverURL: coverURL(coverID: doc.coverID),
            pageCount: nil,
            publicationYear: doc.firstPublishYear,
            isbn10: doc.isbn?.first(where: { $0.count == 10 }),
            isbn13: doc.isbn?.first(where: { $0.count == 13 })
        )
    }

    private static func coverURL(coverID: Int?) -> URL? {
        guard let coverID else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
    }

    private static func extractYear(from firstPublishDate: String?) -> Int? {
        guard let firstPublishDate else { return nil }
        let digits = firstPublishDate.prefix(4)
        return Int(digits)
    }
}

private struct OpenLibrarySearchResponse: Decodable {
    let docs: [OpenLibrarySearchDocument]
}

private struct OpenLibrarySearchDocument: Decodable {
    let key: String
    let title: String
    let authorName: [String]?
    let authorKey: [String]?
    let firstPublishYear: Int?
    let coverID: Int?
    let isbn: [String]?
    let subject: [String]?

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case authorKey = "author_key"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case isbn
        case subject
    }
}

private struct OpenLibraryWorkResponse: Decodable {
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

private struct OpenLibraryDescription: Decodable {
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

private struct OpenLibraryAuthorReference: Decodable {
    let author: OpenLibraryKeyReference
}

private struct OpenLibraryKeyReference: Decodable {
    let key: String
}

private struct OpenLibraryAuthorResponse: Decodable {
    let name: String
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
