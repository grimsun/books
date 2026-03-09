import Foundation

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

    static let defaultUser = User(id: "user_vlad", displayName: "Vlad")

    static let defaultPreferences = UserPreferenceProfile(
        favoriteGenres: [fantasy, literary],
        favoriteAuthors: [leGuin, butler],
        dislikedGenres: [],
        readingPace: .moderate
    )

    static let currentGoal = ReadingGoal(year: 2026, booksTarget: 24, booksCompleted: 7)
}
