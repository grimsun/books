import Foundation

@MainActor
final class LocalProfileRepository: ProfileRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func fetchPreferences() async throws -> UserPreferenceProfile {
        guard let data = defaults.data(forKey: "profile.preferences") else { return .empty }
        return try JSONDecoder().decode(UserPreferenceProfile.self, from: data)
    }

    func updatePreferences(_ profile: UserPreferenceProfile) async throws {
        defaults.set(try JSONEncoder().encode(profile), forKey: "profile.preferences")
    }
}
