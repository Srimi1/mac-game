import Foundation

protocol KeyValueStoring {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}
extension UserDefaults: KeyValueStoring { }

struct PersistenceStore {
    private let store: KeyValueStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(store: KeyValueStoring = UserDefaults.standard) {
        self.store = store
    }

    func loadProgress() -> CampaignProgress {
        load(CampaignProgress.self, key: "campaignProgress") ?? CampaignProgress()
    }

    func save(progress: CampaignProgress) {
        save(progress, key: "campaignProgress")
    }

    func loadSettings() -> PlayerSettings {
        load(PlayerSettings.self, key: "playerSettings") ?? PlayerSettings()
    }

    func save(settings: PlayerSettings) {
        save(settings, key: "playerSettings")
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        store.set(data, forKey: key)
    }
}
