import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
}

struct UserPreferenceProfile: Codable, Equatable {
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

struct Author: Identifiable, Codable, Hashable {
    let id: String
    let name: String
}

struct Genre: Identifiable, Codable, Hashable {
    let id: String
    let name: String
}

struct Book: Identifiable, Codable, Hashable {
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

enum Shelf: String, Codable, CaseIterable, Identifiable {
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

enum ProgressUnit: String, Codable {
    case page
    case percent
}

enum ReadingPace: String, Codable, CaseIterable, Identifiable {
    case slow
    case moderate
    case fast

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct ReadingProgress: Codable, Hashable {
    var progressUnit: ProgressUnit
    var progressValue: Int
}

struct LibraryItem: Identifiable, Codable, Equatable {
    var id: String { book.id }
    let book: Book
    var shelf: Shelf
    var owned: Bool
    var personalRating: Int?
    var privateNote: String?
    var progress: ReadingProgress?
}

struct ReadingGoal: Codable, Equatable {
    let year: Int
    var booksTarget: Int
    var booksCompleted: Int
}

struct RecommendationItem: Identifiable, Codable, Equatable {
    var id: String { book.id }
    let book: Book
    let reason: String
    let score: Double
}
