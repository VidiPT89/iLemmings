import Foundation

/// Persists the best star rating (0-3) earned per level.
enum StarsStore {
    private static func key(_ levelID: String) -> String { "stars_\(levelID)" }

    static func stars(for levelID: String) -> Int {
        UserDefaults.standard.integer(forKey: key(levelID))
    }

    @discardableResult
    static func record(_ stars: Int, for levelID: String) -> Int {
        let best = max(stars, self.stars(for: levelID))
        UserDefaults.standard.set(best, forKey: key(levelID))
        return best
    }
}
