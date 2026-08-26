import CoreAudio
import Foundation

@main
enum PriorityPolicyTests {
  static func main() {
    choosesFirstAvailablePriority()
    fallsBackToNextConnectedPriority()
    ignoresUnrankedDevices()
    emptyPriorityHasNoTarget()
    availableDeviceOrderDoesNotOverridePriority()
    duplicateDeviceUIDsDoNotCrash()
    preferencesRoundTrip()
    legacyPreferencesDecode()
    corruptPreferencesFallBackSafely()
    print("Priority policy tests passed")
  }

  private static func choosesFirstAvailablePriority() {
    let builtIn = device(id: 1, uid: "built-in", name: "MacBook Microphone")
    let usb = device(id: 2, uid: "usb", name: "Studio Mic")
    let result = PriorityPolicy.preferredDevice(
      priorityUIDs: ["usb", "built-in"], availableDevices: [builtIn, usb]
    )
    precondition(result?.uid == "usb")
  }

  private static func fallsBackToNextConnectedPriority() {
    let builtIn = device(id: 1, uid: "built-in", name: "MacBook Microphone")
    let result = PriorityPolicy.preferredDevice(
      priorityUIDs: ["disconnected-usb", "built-in"], availableDevices: [builtIn]
    )
    precondition(result?.uid == "built-in")
  }

  private static func ignoresUnrankedDevices() {
    let airPods = device(id: 3, uid: "airpods", name: "AirPods")
    let result = PriorityPolicy.preferredDevice(
      priorityUIDs: ["studio-mic"], availableDevices: [airPods]
    )
    precondition(result == nil)
  }

  private static func emptyPriorityHasNoTarget() {
    let builtIn = device(id: 1, uid: "built-in", name: "MacBook Microphone")
    precondition(
      PriorityPolicy.preferredDevice(priorityUIDs: [], availableDevices: [builtIn]) == nil)
  }

  private static func availableDeviceOrderDoesNotOverridePriority() {
    let firstAvailable = device(id: 1, uid: "lower", name: "Lower Priority")
    let secondAvailable = device(id: 2, uid: "higher", name: "Higher Priority")
    let result = PriorityPolicy.preferredDevice(
      priorityUIDs: ["higher", "lower"],
      availableDevices: [firstAvailable, secondAvailable]
    )
    precondition(result?.uid == "higher")
  }

  private static func duplicateDeviceUIDsDoNotCrash() {
    let first = device(id: 1, uid: "duplicate", name: "First Instance")
    let second = device(id: 2, uid: "duplicate", name: "Second Instance")
    let result = PriorityPolicy.preferredDevice(
      priorityUIDs: ["duplicate"],
      availableDevices: [first, second]
    )
    precondition(result?.id == 1)
  }

  private static func preferencesRoundTrip() {
    withTemporaryDefaults { defaults in
      let store = PreferencesStore(defaults: defaults)
      let expected = SavedPreferences(
        isEnabled: false,
        microphones: [StoredMicrophone(uid: "usb", name: "Studio Mic")],
        hasCompletedSetup: true
      )
      store.save(expected)
      precondition(store.load() == expected)
    }
  }

  private static func legacyPreferencesDecode() {
    withTemporaryDefaults { defaults in
      let json = #"{"isEnabled":true,"microphones":[{"uid":"legacy","name":"Legacy Mic"}]}"#
      defaults.set(Data(json.utf8), forKey: "savedPreferences.v1")
      let loaded = PreferencesStore(defaults: defaults).load()
      precondition(loaded.hasCompletedSetup)
      precondition(loaded.microphones.first?.uid == "legacy")
    }
  }

  private static func corruptPreferencesFallBackSafely() {
    withTemporaryDefaults { defaults in
      defaults.set(Data("not-json".utf8), forKey: "savedPreferences.v1")
      precondition(PreferencesStore(defaults: defaults).load() == SavedPreferences())
    }
  }

  private static func withTemporaryDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "dev.rallen.macos-mic-priority.tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else { preconditionFailure() }
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(defaults)
  }

  private static func device(id: AudioObjectID, uid: String, name: String) -> AudioDevice {
    AudioDevice(
      id: id,
      uid: uid,
      name: name,
      transportType: kAudioDeviceTransportTypeBuiltIn,
      isDefault: false
    )
  }
}
