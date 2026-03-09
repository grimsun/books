import Foundation
import Observation

@Observable
final class SessionStore {
    var currentUser: User?
    var hasCompletedOnboarding = false
}

@Observable
final class AppEnvironment {
    let authRepository: any AuthRepository
    let booksRepository: any BooksRepository
    let libraryRepository: any LibraryRepository
    let recommendationsRepository: any RecommendationsRepository
    let profileRepository: any ProfileRepository
    let goalsRepository: any GoalsRepository
    let session = SessionStore()

    init(
        authRepository: any AuthRepository,
        booksRepository: any BooksRepository,
        libraryRepository: any LibraryRepository,
        recommendationsRepository: any RecommendationsRepository,
        profileRepository: any ProfileRepository,
        goalsRepository: any GoalsRepository
    ) {
        self.authRepository = authRepository
        self.booksRepository = booksRepository
        self.libraryRepository = libraryRepository
        self.recommendationsRepository = recommendationsRepository
        self.profileRepository = profileRepository
        self.goalsRepository = goalsRepository
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
}
