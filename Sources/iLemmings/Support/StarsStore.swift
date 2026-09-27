import Foundation

/// Persists the best star rating (0-3) earned per level.
enum StarsStore {
    static func key(_ levelID: String) -> String { "stars_\(levelID)" }

    static func stars(for levelID: String) -> Int {
        UserDefaults.standard.integer(forKey: key(levelID))
    }

    /// Keeps the best rating: a worse replay never lowers it.
    static func record(_ stars: Int, for levelID: String) {
        UserDefaults.standard.set(max(stars, self.stars(for: levelID)), forKey: key(levelID))
    }
}
