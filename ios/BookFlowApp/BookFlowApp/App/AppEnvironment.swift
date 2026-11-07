import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    private let defaults: UserDefaults?
    var currentUser: User? {
        didSet { defaults?.set(try? JSONEncoder().encode(currentUser), forKey: "session.user") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults?.set(hasCompletedOnboarding, forKey: "session.onboarded") }
    }
    var showWeeklyRhythm: Bool {
        didSet { defaults?.set(showWeeklyRhythm, forKey: "session.rhythmVisible") }
    }
    private var completedDates: Set<String> {
        didSet { defaults?.set(Array(completedDates), forKey: "session.readingDates") }
    }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        currentUser = defaults?.data(forKey: "session.user").flatMap { try? JSONDecoder().decode(User.self, from: $0) }
        hasCompletedOnboarding = defaults?.bool(forKey: "session.onboarded") ?? false
        showWeeklyRhythm = defaults?.object(forKey: "session.rhythmVisible") as? Bool ?? true
        completedDates = Set(defaults?.stringArray(forKey: "session.readingDates") ?? [])
    }

    func readingDays(now: Date = Date(), calendar: Calendar = .current) -> [ReadingDayStatus] {
        // Keep the Monday-first rail stable across locale-specific week starts.
        let today = calendar.startOfDay(for: now)
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offset, to: today) else { return [] }
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: monday) else { return nil }
            let key = dateKey(date, calendar: calendar)
            return ReadingDayStatus(id: key, label: ["M", "T", "W", "T", "F", "S", "S"][index],
                                    isCompleted: completedDates.contains(key), isToday: calendar.isDate(date, inSameDayAs: today), date: date)
        }
    }

    func toggleReading(on date: Date, now: Date = Date(), calendar: Calendar = .current) {
        guard calendar.startOfDay(for: date) <= calendar.startOfDay(for: now) else { return }
        let key = dateKey(date, calendar: calendar)
        if completedDates.contains(key) {
            completedDates.remove(key)
        } else {
            completedDates.insert(key)
        }
    }

    private func dateKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

@Observable
@MainActor
final class AppEnvironment {
    let authRepository: any AuthRepository
    let booksRepository: any BooksRepository
    let libraryRepository: any LibraryRepository
    let recommendationsRepository: any RecommendationsRepository
    let profileRepository: any ProfileRepository
    let goalsRepository: any GoalsRepository
    let session: SessionStore
    var libraryRevision = 0
    let homeFeed = HomeFeedStore()

    init(
        authRepository: any AuthRepository,
        booksRepository: any BooksRepository,
        libraryRepository: any LibraryRepository,
        recommendationsRepository: any RecommendationsRepository,
        profileRepository: any ProfileRepository,
        goalsRepository: any GoalsRepository,
        session: SessionStore? = nil
    ) {
        self.authRepository = authRepository
        self.booksRepository = booksRepository
        self.libraryRepository = libraryRepository
        self.recommendationsRepository = recommendationsRepository
        self.profileRepository = profileRepository
        self.goalsRepository = goalsRepository
        self.session = session ?? SessionStore()
    }

    static func mock() -> AppEnvironment {
        AppEnvironment(
            authRepository: MockAuthRepository(),
            booksRepository: MockBooksRepository(),
            libraryRepository: MockLibraryRepository(),
            recommendationsRepository: MockRecommendationsRepository(),
            profileRepository: MockProfileRepository(),
            goalsRepository: MockGoalsRepository()
        )
    }

    static func liveBooks() -> AppEnvironment {
        let books = OpenLibraryBooksRepository()
        let storageURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bookflow/library.json")
        return AppEnvironment(
            authRepository: MockAuthRepository(),
            booksRepository: books,
            libraryRepository: LocalLibraryRepository(booksRepository: books, storageURL: storageURL, seedItems: MockSeedData.libraryItems),
            recommendationsRepository: MockRecommendationsRepository(),
            profileRepository: LocalProfileRepository(defaults: .standard),
            goalsRepository: MockGoalsRepository(),
            session: SessionStore(defaults: .standard)
        )
    }

    static func app() -> AppEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BOOKFLOW_UI_TESTING"] == "1" {
            let defaults = UserDefaults(suiteName: "Bookflow.UITests")!
            let storageURL = FileManager.default.temporaryDirectory.appendingPathComponent("BookflowUITests/library.json")
            if ProcessInfo.processInfo.environment["BOOKFLOW_RESET_TEST_DATA"] == "1" {
                defaults.removePersistentDomain(forName: "Bookflow.UITests")
                try? FileManager.default.removeItem(at: storageURL)
            }
            let books = MockBooksRepository()
            let seedItems: [LibraryItem]
            if ProcessInfo.processInfo.environment["BOOKFLOW_LARGE_LIBRARY"] == "1" {
                seedItems = (0..<1_000).map { index in
                    let sample = MockSeedData.books[index % MockSeedData.books.count]
                    let book = Book(id: "stress-\(index)", title: sample.title, subtitle: sample.subtitle,
                                    authors: sample.authors, genres: sample.genres, description: sample.description,
                                    coverURL: sample.coverURL, pageCount: sample.pageCount,
                                    publicationYear: sample.publicationYear, isbn10: sample.isbn10, isbn13: sample.isbn13)
                    return LibraryItem(book: book, shelf: index.isMultiple(of: 2) ? .reading : .wantToRead, owned: false)
                }
            } else {
                seedItems = MockSeedData.libraryItems
            }
            return AppEnvironment(
                authRepository: MockAuthRepository(),
                booksRepository: books,
                libraryRepository: LocalLibraryRepository(booksRepository: books, storageURL: storageURL, seedItems: seedItems),
                recommendationsRepository: MockRecommendationsRepository(),
                profileRepository: LocalProfileRepository(defaults: defaults),
                goalsRepository: MockGoalsRepository(),
                session: SessionStore(defaults: defaults)
            )
        }
        #endif
        return liveBooks()
    }
}
