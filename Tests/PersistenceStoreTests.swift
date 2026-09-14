import XCTest
@testable import BreakTheQuietDays

final class PersistenceStoreTests: XCTestCase {
    func testProgressRoundTrip() {
        let memory = MemoryStore()
        let persistence = PersistenceStore(store: memory)
        let expected = CampaignProgress(highestUnlockedIndex: 7, bestScores: ["day1-1": 4200], stars: ["day1-1": 3], campaignCompleted: false)

        persistence.save(progress: expected)

        XCTAssertEqual(persistence.loadProgress(), expected)
    }

    func testSettingsRoundTrip() {
        let memory = MemoryStore()
        let persistence = PersistenceStore(store: memory)
        let expected = PlayerSettings(musicVolume: 0.1, effectsVolume: 0.8, reducedMotion: true, aimGuide: false)

        persistence.save(settings: expected)

        XCTAssertEqual(persistence.loadSettings(), expected)
    }

    func testCorruptDataFallsBackToDefaults() {
        let memory = MemoryStore()
        memory.set(Data("not-json".utf8), forKey: "campaignProgress")
        XCTAssertEqual(PersistenceStore(store: memory).loadProgress(), CampaignProgress())
    }
}
private final class MemoryStore: KeyValueStoring {
    private var values: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
