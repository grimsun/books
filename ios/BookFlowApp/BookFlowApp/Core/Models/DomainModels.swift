import Foundation

nonisolated struct User: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var displayName: String
}

nonisolated struct UserPreferenceProfile: Codable, Equatable, Sendable {
    var favoriteGenres: [Genre]
    var favoriteAuthors: [Author]
    var dislikedGenres: [Genre]
    var readingPace: ReadingPace

    static let empty = UserPreferenceProfile(
        favoriteGenres: [],
        favoriteAuthors: [],
        dislikedGenres: [],
        readingPace: .moderate
    )
}

nonisolated struct Author: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
}

nonisolated struct Genre: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
}

nonisolated struct Book: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let authors: [Author]
    let genres: [Genre]
    let description: String?
    let coverURL: URL?
    let pageCount: Int?
    let publicationYear: Int?
    let isbn10: String?
    let isbn13: String?
}

nonisolated enum Shelf: String, Codable, CaseIterable, Identifiable, Sendable {
    case wantToRead = "want_to_read"
    case reading
    case finished
    case paused
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        case .paused: return "Paused"
        case .dropped: return "Dropped"
        }
    }
}

nonisolated enum ProgressUnit: String, Codable, Sendable {
    case page
    case percent
}

nonisolated enum ReadingPace: String, Codable, CaseIterable, Identifiable, Sendable {
    case slow
    case moderate
    case fast

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

nonisolated struct ReadingProgress: Codable, Hashable, Sendable {
    var progressUnit: ProgressUnit
    var progressValue: Int

    func fraction(pageCount: Int?) -> Double? {
        let total: Int
        switch progressUnit {
        case .page:
            guard let pageCount, pageCount > 0 else { return nil }
            total = pageCount
        case .percent:
            total = 100
        }
        return min(max(Double(progressValue) / Double(total), 0), 1)
    }

    var label: String {
        progressUnit == .page ? "Page \(progressValue)" : "\(progressValue)% complete"
    }
}

nonisolated struct LibraryItem: Identifiable, Codable, Equatable, Sendable {
    var id: String { book.id }
    let book: Book
    var shelf: Shelf
    var owned: Bool
    var personalRating: Int?
    var privateNote: String?
    var progress: ReadingProgress?
}

nonisolated struct ReadingGoal: Codable, Equatable, Sendable {
    let year: Int
    var booksTarget: Int
    var booksCompleted: Int
}

nonisolated struct RecommendationItem: Identifiable, Codable, Equatable, Sendable {
    var id: String { book.id }
    let book: Book
    let reason: String
    let score: Double
}
