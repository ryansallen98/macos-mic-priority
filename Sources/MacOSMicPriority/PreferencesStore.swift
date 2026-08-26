import Foundation

struct SavedPreferences: Codable, Equatable, Sendable {
  var isEnabled = true
  var microphones: [StoredMicrophone] = []
  var hasCompletedSetup = false

  private enum CodingKeys: String, CodingKey {
    case isEnabled
    case microphones
    case hasCompletedSetup
  }

  init(
    isEnabled: Bool = true,
    microphones: [StoredMicrophone] = [],
    hasCompletedSetup: Bool = false
  ) {
    self.isEnabled = isEnabled
    self.microphones = microphones
    self.hasCompletedSetup = hasCompletedSetup
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    microphones = try container.decodeIfPresent([StoredMicrophone].self, forKey: .microphones) ?? []
    hasCompletedSetup =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup)
      ?? !microphones.isEmpty
  }
}

protocol PreferencesStoring: AnyObject {
  func load() -> SavedPreferences
  func save(_ preferences: SavedPreferences)
}

final class PreferencesStore: PreferencesStoring {
  private enum Key {
    static let preferences = "savedPreferences.v1"
  }

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> SavedPreferences {
    guard let data = defaults.data(forKey: Key.preferences),
      let value = try? decoder.decode(SavedPreferences.self, from: data)
    else { return SavedPreferences() }
    return value
  }

  func save(_ preferences: SavedPreferences) {
    guard let data = try? encoder.encode(preferences) else { return }
    defaults.set(data, forKey: Key.preferences)
  }
}
