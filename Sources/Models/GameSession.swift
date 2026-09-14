import Foundation
import Observation

@MainActor
@Observable
final class GameSession {
    private let persistence: PersistenceStore

    var route: AppRoute = .home
    var progress: CampaignProgress
    var settings: PlayerSettings
    var selectedLevel: LevelDefinition?
    var lastResult: LevelResult?

    init(persistence: PersistenceStore = PersistenceStore()) {
        self.persistence = persistence
        progress = persistence.loadProgress()
        settings = persistence.loadSettings()

        // Players who finished the original 18-room campaign continue directly
        // into the two newly added days instead of having to replay the old finale.
        if progress.campaignCompleted, progress.highestUnlockedIndex == 17, LevelCatalog.levels.count > 18 {
            progress.highestUnlockedIndex = 18
            progress.campaignCompleted = false
            persistence.save(progress: progress)
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--unlock-all") {
            progress.highestUnlockedIndex = max(0, LevelCatalog.levels.count - 1)
        }
        #endif
    }

    var continueLevel: LevelDefinition? {
        guard !LevelCatalog.levels.isEmpty else { return nil }
        let index = min(progress.highestUnlockedIndex, LevelCatalog.levels.count - 1)
        return LevelCatalog.levels[index]
    }

    func showHome() { route = .home }
    func showDaySelect() { route = .daySelect }
    func showSettings() { route = .settings }
    func showCredits() { route = .credits }

    func play(_ level: LevelDefinition) {
        guard isUnlocked(level) else { return }
        selectedLevel = level
        lastResult = nil
        route = .game
    }

    func retry() {
        guard selectedLevel != nil else { return }
        route = .game
    }

    func complete(_ result: LevelResult) {
        lastResult = result
        guard result.didComplete, let level = LevelCatalog.level(id: result.levelID) else {
            route = .results
            return
        }

        progress.bestScores[result.levelID] = max(progress.bestScores[result.levelID] ?? 0, result.score)
        progress.stars[result.levelID] = max(progress.stars[result.levelID] ?? 0, result.stars)
        progress.highestUnlockedIndex = min(LevelCatalog.levels.count - 1, max(progress.highestUnlockedIndex, level.globalIndex + 1))

        if level.globalIndex == LevelCatalog.levels.count - 1 {
            progress.campaignCompleted = true
            route = .finale
        } else {
            route = .results
        }
        persistence.save(progress: progress)
    }

    func playNext() {
        guard let level = selectedLevel else { return }
        let nextIndex = level.globalIndex + 1
        guard LevelCatalog.levels.indices.contains(nextIndex) else {
            route = .finale
            return
        }
        play(LevelCatalog.levels[nextIndex])
    }

    func isUnlocked(_ level: LevelDefinition) -> Bool {
        level.globalIndex <= progress.highestUnlockedIndex
    }

    func saveSettings() {
        settings.musicVolume = min(1, max(0, settings.musicVolume))
        settings.effectsVolume = min(1, max(0, settings.effectsVolume))
        persistence.save(settings: settings)
    }
}
