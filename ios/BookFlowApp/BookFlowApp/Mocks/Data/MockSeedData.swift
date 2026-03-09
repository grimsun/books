import Foundation

struct PopularBookTile: Identifiable, Hashable {
    let id: String
    let assetName: String
    let bookID: String
}

struct CuratedBookList: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let bookIDs: [String]
}

struct MoodRecommendationShelf: Identifiable, Hashable {
    let id: String
    let title: String
    let recommendationBookIDs: [String]
}

struct ReadingDayStatus: Identifiable, Hashable {
    let id: String
    let label: String
    var isCompleted: Bool
    let isToday: Bool
}

enum MockSeedData {
    static let leGuin = Author(id: "author_leguin", name: "Ursula K. Le Guin")
    static let martel = Author(id: "author_martel", name: "Yann Martel")
    static let butler = Author(id: "author_butler", name: "Octavia E. Butler")
    static let murakami = Author(id: "author_murakami", name: "Haruki Murakami")

    static let fantasy = Genre(id: "genre_fantasy", name: "Fantasy")
    static let literary = Genre(id: "genre_literary", name: "Literary Fiction")
    static let sciFi = Genre(id: "genre_scifi", name: "Science Fiction")
    static let classics = Genre(id: "genre_classics", name: "Classics")

    static let books: [Book] = [
        Book(
            id: "book_earthsea",
            title: "A Wizard of Earthsea",
            subtitle: nil,
            authors: [leGuin],
            genres: [fantasy],
            description: "A young wizard grows into power, responsibility, and restraint.",
            coverURL: URL(string: "https://covers.openlibrary.org/b/id/146576-L.jpg"),
            pageCount: 205,
            publicationYear: 1968,
            isbn10: "0553383044",
            isbn13: "9780553383041"
        ),
        Book(
            id: "book_left_hand",
            title: "The Left Hand of Darkness",
            subtitle: nil,
            authors: [leGuin],
            genres: [sciFi, literary],
            description: "A diplomat navigates politics, culture, and identity on a frozen world.",
            coverURL: URL(string: "https://covers.openlibrary.org/b/id/240726-L.jpg"),
            pageCount: 304,
            publicationYear: 1969,
            isbn10: "0441478123",
            isbn13: "9780441478125"
        ),
        Book(
            id: "book_kindred",
            title: "Kindred",
            subtitle: nil,
            authors: [butler],
            genres: [sciFi, classics],
            description: "A modern Black woman is pulled repeatedly into the antebellum South.",
            coverURL: URL(string: "https://covers.openlibrary.org/b/id/8231856-L.jpg"),
            pageCount: 288,
            publicationYear: 1979,
            isbn10: "0807083690",
            isbn13: "9780807083697"
        ),
        Book(
            id: "book_kafka",
            title: "Kafka on the Shore",
            subtitle: nil,
            authors: [murakami],
            genres: [literary, fantasy],
            description: "A surreal coming-of-age journey braided with metaphysical mystery.",
            coverURL: URL(string: "https://covers.openlibrary.org/b/id/240727-L.jpg"),
            pageCount: 505,
            publicationYear: 2002,
            isbn10: "1400079276",
            isbn13: "9781400079278"
        ),
        Book(
            id: "book_life_of_pi",
            title: "Life of Pi",
            subtitle: nil,
            authors: [martel],
            genres: [literary],
            description: "A shipwreck survivor tells an astonishing story of survival and belief.",
            coverURL: URL(string: "https://covers.openlibrary.org/b/id/240728-L.jpg"),
            pageCount: 352,
            publicationYear: 2001,
            isbn10: "0156027321",
            isbn13: "9780156027328"
        )
    ]

    static let libraryItems: [LibraryItem] = [
        LibraryItem(
            book: books[1],
            shelf: .reading,
            owned: true,
            personalRating: nil,
            privateNote: "Strong first third.",
            progress: ReadingProgress(progressUnit: .page, progressValue: 128)
        ),
        LibraryItem(
            book: books[3],
            shelf: .reading,
            owned: false,
            personalRating: nil,
            privateNote: "Very atmospheric.",
            progress: ReadingProgress(progressUnit: .page, progressValue: 221)
        ),
        LibraryItem(
            book: books[2],
            shelf: .finished,
            owned: true,
            personalRating: 5,
            privateNote: "Will revisit.",
            progress: ReadingProgress(progressUnit: .page, progressValue: 288)
        ),
        LibraryItem(
            book: books[0],
            shelf: .wantToRead,
            owned: false,
            personalRating: nil,
            privateNote: nil,
            progress: nil
        )
    ]

    static let recommendations: [RecommendationItem] = [
        RecommendationItem(book: books[0], reason: "Similar to the speculative fiction you save most often", score: 0.93),
        RecommendationItem(book: books[3], reason: "Blends literary tone with strange, immersive worldbuilding", score: 0.89),
        RecommendationItem(book: books[4], reason: "A high-signal literary pick with strong completion rates", score: 0.81)
    ]

    static let popularTiles: [PopularBookTile] = [
        PopularBookTile(id: "popular_1", assetName: "Popular1", bookID: books[4].id),
        PopularBookTile(id: "popular_2", assetName: "Popular2", bookID: books[0].id),
        PopularBookTile(id: "popular_3", assetName: "Popular3", bookID: books[2].id),
        PopularBookTile(id: "popular_4", assetName: "Popular4", bookID: books[3].id),
        PopularBookTile(id: "popular_5", assetName: "Popular5", bookID: books[1].id),
        PopularBookTile(id: "popular_6", assetName: "Popular6", bookID: books[0].id),
        PopularBookTile(id: "popular_7", assetName: "Popular7", bookID: books[3].id),
        PopularBookTile(id: "popular_8", assetName: "Popular8", bookID: books[2].id),
        PopularBookTile(id: "popular_9", assetName: "Popular9", bookID: books[4].id),
        PopularBookTile(id: "popular_10", assetName: "Popular2", bookID: books[1].id),
        PopularBookTile(id: "popular_11", assetName: "Popular4", bookID: books[0].id),
        PopularBookTile(id: "popular_12", assetName: "Popular7", bookID: books[2].id)
    ]

    static let curatedLists: [CuratedBookList] = [
        CuratedBookList(
            id: "list_fantasy",
            title: "Best fantasy books",
            subtitle: "Worldbuilding-heavy picks",
            bookIDs: [books[0].id, books[3].id, books[1].id, books[2].id, books[4].id]
        ),
        CuratedBookList(
            id: "list_literary",
            title: "Quiet literary novels",
            subtitle: "Slow-burn and memorable",
            bookIDs: [books[4].id, books[3].id, books[1].id, books[2].id]
        ),
        CuratedBookList(
            id: "list_speculative",
            title: "Speculative essentials",
            subtitle: "Canonical and modern",
            bookIDs: [books[1].id, books[2].id, books[0].id, books[3].id, books[4].id]
        )
    ]

    static let moodShelves: [MoodRecommendationShelf] = [
        MoodRecommendationShelf(id: "mood_immersive", title: "Immersive", recommendationBookIDs: [books[3].id, books[1].id, books[0].id]),
        MoodRecommendationShelf(id: "mood_short", title: "Short", recommendationBookIDs: [books[0].id, books[2].id, books[4].id]),
        MoodRecommendationShelf(id: "mood_strange", title: "Strange", recommendationBookIDs: [books[3].id, books[2].id, books[1].id]),
        MoodRecommendationShelf(id: "mood_comfort", title: "Comfort", recommendationBookIDs: [books[4].id, books[0].id, books[3].id]),
        MoodRecommendationShelf(id: "mood_heavy", title: "Heavy", recommendationBookIDs: [books[2].id, books[1].id, books[4].id]),
        MoodRecommendationShelf(id: "mood_smart", title: "Smart", recommendationBookIDs: [books[1].id, books[3].id, books[2].id])
    ]

    static let weeklyReadingStatus: [ReadingDayStatus] = [
        ReadingDayStatus(id: "mon", label: "M", isCompleted: true, isToday: false),
        ReadingDayStatus(id: "tue", label: "T", isCompleted: false, isToday: false),
        ReadingDayStatus(id: "wed", label: "W", isCompleted: true, isToday: false),
        ReadingDayStatus(id: "thu", label: "T", isCompleted: false, isToday: false),
        ReadingDayStatus(id: "fri", label: "F", isCompleted: true, isToday: false),
        ReadingDayStatus(id: "sat", label: "S", isCompleted: false, isToday: false),
        ReadingDayStatus(id: "sun", label: "S", isCompleted: false, isToday: true)
    ]

    static let defaultUser = User(id: "user_vlad", displayName: "Vlad")

    static let defaultPreferences = UserPreferenceProfile(
        favoriteGenres: [fantasy, literary],
        favoriteAuthors: [leGuin, butler],
        dislikedGenres: [],
        readingPace: .moderate
    )

    static let currentGoal = ReadingGoal(year: 2026, booksTarget: 24, booksCompleted: 7)
}
